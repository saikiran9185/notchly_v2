import Foundation

/// TaskStore — manages task queue from Python brain
/// Watches ~/notchly/v2/queue/tasks.json with DispatchSource
final class TaskStore {
    static let shared = TaskStore()

    private let queueDir: URL
    private let tasksURL: URL
    private var fileSource: DispatchSourceFileSystemObject?
    private var debounceTimer: Timer?

    private(set) var taskQueue: [NotchTask] = []

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        queueDir = home.appendingPathComponent("notchly/v2/queue")
        tasksURL = queueDir.appendingPathComponent("tasks.json")
    }

    func start() {
        ensureDir()
        startWatcher()
        reload()
    }

    private func ensureDir() {
        try? FileManager.default.createDirectory(
            at: queueDir,
            withIntermediateDirectories: true
        )
    }

    private func startWatcher() {
        let fd = open(queueDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .global(qos: .utility)
        )
        fileSource?.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        fileSource?.setCancelHandler { close(fd) }
        fileSource?.resume()
    }

    private func scheduleReload() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.reload()
        }
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: tasksURL.path),
              let data = try? Data(contentsOf: tasksURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasks = json["tasks"] as? [[String: Any]] else {
            return
        }

        let parsed = tasks.compactMap { parseTask($0) }
        DispatchQueue.main.async {
            self.taskQueue = parsed
            NotchState.shared.taskQueue = parsed
        }
    }

    private func parseTask(_ dict: [String: Any]) -> NotchTask? {
        guard let title = dict["title"] as? String else { return nil }
        var task = NotchTask(title: title)

        if let idStr = dict["id"] as? String, let uuid = UUID(uuidString: idStr) {
            task.id = uuid
        }
        task.subtitle = dict["subtitle"] as? String ?? ""

        if let catStr = dict["type"] as? String {
            task.category = TaskCategory(rawValue: catStr) ?? .other
        }

        task.estimatedMinutes = dict["duration_minutes"] as? Int ?? 30
        task.progressPercent = dict["progress_pct"] as? Double ?? 0
        task.pFinal = dict["priority"] as? Double ?? 5.0
        task.relatedAppBundleID = dict["app_bundle"] as? String
        task.isCompleted = dict["is_done"] as? Bool ?? false

        if let deadline = dict["deadline"] as? TimeInterval {
            task.deadline = Date(timeIntervalSince1970: deadline)
        }

        return task
    }

    // MARK: - Actions
    func markDone(id: UUID) {
        if let idx = taskQueue.firstIndex(where: { $0.id == id }) {
            taskQueue[idx].isCompleted = true
            sync()
        }
        BridgeWatcher.shared.sendCommand("task_done", payload: ["task_id": id.uuidString])
        NotchState.shared.taskQueue = taskQueue
    }

    func markSkipped(id: UUID) {
        if let idx = taskQueue.firstIndex(where: { $0.id == id }) {
            taskQueue[idx].skipCount += 1
            sync()
        }
        BridgeWatcher.shared.sendCommand("task_skip", payload: ["task_id": id.uuidString])
        NotchState.shared.taskQueue = taskQueue
    }

    func markLater(id: UUID) {
        BridgeWatcher.shared.sendCommand("task_later", payload: ["task_id": id.uuidString])
    }

    private func sync() {
        let tasks = taskQueue.map { task -> [String: Any] in
            var dict: [String: Any] = [
                "id": task.id.uuidString,
                "title": task.title,
                "type": task.category.rawValue,
                "duration_minutes": task.estimatedMinutes,
                "progress_pct": task.progressPercent,
                "priority": task.pFinal,
                "is_done": task.isCompleted,
                "skip_count": task.skipCount
            ]
            dict["subtitle"] = task.subtitle
            if let bundle = task.relatedAppBundleID { dict["app_bundle"] = bundle }
            if let deadline = task.deadline { dict["deadline"] = deadline.timeIntervalSince1970 }
            return dict
        }

        let json: [String: Any] = [
            "tasks": tasks,
            "updated_at": Date().timeIntervalSince1970
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return }
        try? data.write(to: tasksURL, options: .atomic)
    }

    deinit {
        fileSource?.cancel()
        debounceTimer?.invalidate()
    }
}

// MARK: - Current/next task accessors
extension TaskStore {
    var currentTask: NotchTask? {
        taskQueue.first { !$0.isCompleted }
    }

    var nextTask: NotchTask? {
        let remaining = taskQueue.filter { !$0.isCompleted }
        return remaining.count > 1 ? remaining[1] : nil
    }
}
