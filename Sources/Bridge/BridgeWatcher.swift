import Foundation
import AppKit

/// IPC Bridge between Swift and Python brain
/// Swift sends commands → Python responds via JSON files
final class BridgeWatcher {
    static let shared = BridgeWatcher()

    private let bridgeDir: URL
    private let commandURL: URL
    private let responseURL: URL

    private var fileSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    // BUG-21 fix: use a lock to protect lastResponseTS from concurrent read/write
    // by both the file-watcher callback and the poll timer
    private let responseLock = NSLock()
    private var _lastResponseTS: TimeInterval = 0
    private var lastResponseTS: TimeInterval {
        get { responseLock.lock(); defer { responseLock.unlock() }; return _lastResponseTS }
        set { responseLock.lock(); defer { responseLock.unlock() }; _lastResponseTS = newValue }
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        bridgeDir = home.appendingPathComponent("notchly/v2/bridge")
        commandURL = bridgeDir.appendingPathComponent("command.json")
        responseURL = bridgeDir.appendingPathComponent("response.json")
    }

    func start() {
        ensureBridgeDir()
        startFileWatcher()
        startPollFallback()
    }

    func stop() {
        fileSource?.cancel()
        pollTimer?.invalidate()
    }

    private func ensureBridgeDir() {
        let dirs = ["bridge", "alerts", "alerts/processed", "queue", "memory", "cache"]
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("notchly/v2")
        for d in dirs {
            try? FileManager.default.createDirectory(
                at: base.appendingPathComponent(d),
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Send command to Python brain
    func sendCommand(_ action: String, payload: [String: Any] = [:]) {
        var cmd: [String: Any] = [
            "action": action,
            "ts": Date().timeIntervalSince1970
        ]
        for (k, v) in payload {
            cmd[k] = v
        }
        guard let data = try? JSONSerialization.data(withJSONObject: cmd, options: .prettyPrinted) else {
            return
        }
        try? data.write(to: commandURL, options: .atomic)
    }

    // MARK: - File watching
    private func startFileWatcher() {
        let fd = open(bridgeDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .global(qos: .utility)
        )
        fileSource?.setEventHandler { [weak self] in
            self?.checkResponse()
        }
        fileSource?.setCancelHandler { close(fd) }
        fileSource?.resume()
    }

    private func startPollFallback() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkResponse()
        }
    }

    private func checkResponse() {
        guard FileManager.default.fileExists(atPath: responseURL.path) else { return }
        guard let data = try? Data(contentsOf: responseURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ts = json["ts"] as? TimeInterval,
              ts > lastResponseTS else { return }

        lastResponseTS = ts
        handleResponse(json)
    }

    private func handleResponse(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "chat_reply":
                if let text = json["text"] as? String {
                    NotchState.shared.receiveChatReply(text)
                }

            case "notification":
                self.handleNotificationPayload(json)

            case "task_update":
                self.handleTaskUpdate(json)

            case "heartbeat":
                if let status = json["status"] as? String {
                    NotchState.shared.aiStatus = status
                }

            default:
                break
            }
        }
    }

    private func handleNotificationPayload(_ json: [String: Any]) {
        guard let title = json["title"] as? String else { return }
        let subtitle = json["subtitle"] as? String ?? ""
        let typeStr = json["notif_type"] as? String ?? "task"
        let notifType = NotifType(rawValue: typeStr) ?? .task

        var notif = NotchNotification(title: title, subtitle: subtitle, type: notifType)
        notif.leftAction = json["left_action"] as? String ?? "Skip"
        notif.rightAction = json["right_action"] as? String ?? "Done"
        
        NotchState.shared.enqueue(notif)
    }

    private func handleTaskUpdate(_ json: [String: Any]) {
        guard let tasks = json["tasks"] as? [[String: Any]] else { return }
        let notchTasks = tasks.compactMap { dict -> NotchTask? in
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
            return task
        }
        NotchState.shared.taskQueue = notchTasks
    }
}
