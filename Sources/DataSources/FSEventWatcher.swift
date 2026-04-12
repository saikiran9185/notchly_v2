import Foundation

// Watches pending_alerts.json for changes from Python brain daemon.
// Uses FSEvents for <100ms response time.
class FSEventWatcher {
    static let shared = FSEventWatcher()
    private init() {}

    private var streamRef: FSEventStreamRef?
    private var callback: (() -> Void)?

    func start() {
        watch(path: DirectorySetup.base.path) { [weak self] in
            self?.onAlertsChanged()
        }
    }

    func watch(path: String, callback: @escaping () -> Void) {
        self.callback = callback
        let paths = [path] as CFArray
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, _, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<FSEventWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.callback?()
            },
            &ctx,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,   // 100ms latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )

        guard let stream = streamRef else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func onAlertsChanged() {
        // Read pending_alerts.json and enqueue any new alerts
        guard let data = try? Data(contentsOf: DirectorySetup.pendingAlerts),
              let alerts = try? JSONDecoder().decode([PendingAlert].self, from: data),
              !alerts.isEmpty
        else { return }

        DispatchQueue.main.async {
            let state = NotchState.shared
            for alert in alerts {
                var notif = NotchNotification(
                    title: alert.title,
                    subtitle: alert.subtitle,
                    type: NotifType(rawValue: alert.type) ?? .other
                )
                // Button placement from ButtonPlacementEngine
                let placed = ButtonPlacementEngine.shared.labels(
                    for: notif.type, context: state.context)
                notif.leftAction   = placed.leftAction
                notif.centerAction = placed.centerAction
                notif.rightAction  = placed.rightAction

                // EVR gate
                let task = state.taskQueue.first { $0.title == alert.taskTitle }
                if let task = task {
                    let profile = SemanticProfile.shared.current
                    if InterruptionGuard.shared.shouldFire(
                        notif, task: task, context: state.context, profile: profile) {
                        state.enqueue(notif)
                    } else {
                        // BUG-7 fix: blocked by EVR — add to retry queue instead of silently dropping
                        ContextEngine.shared.enqueueForRetry(notification: notif, task: task)
                    }
                } else {
                    // No matching task found — fire without EVR gate (urgency-based alerts)
                    state.enqueue(notif)
                }
            }
            // Clear processed alerts atomically
            if let empty = "[]".data(using: .utf8) {
                try? empty.write(to: DirectorySetup.pendingAlerts, options: .atomic)
            }
        }
    }

    deinit {
        if let s = streamRef {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
        }
    }
}

struct PendingAlert: Codable {
    var title: String
    var subtitle: String = ""
    var type: String
    var taskTitle: String = ""
    var urgency: Double = 2.0
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AlertWatcher
// Watches ~/notchly/v2/alerts/ for JSON files dropped by notchly_pulse (Rust).
// Each file is one alert → decoded → enqueued into NotchState → Stage 1A fires.
// ─────────────────────────────────────────────────────────────────────────────

final class AlertWatcher {
    static let shared = AlertWatcher()

    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var seenIDs: Set<String> = []

    private init() {}

    func start() {
        startDispatchSource()
        // Fallback poll every 3s — catches alerts written before watcher started
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.scanAlerts()
        }
        scanAlerts()
    }

    func stop() {
        source?.cancel()
        pollTimer?.invalidate()
    }

    // MARK: - Dispatch source on alerts dir

    private func startDispatchSource() {
        let dir = DirectorySetup.alertsDir
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .global(qos: .userInteractive)
        )
        source?.setEventHandler { [weak self] in self?.scanAlerts() }
        source?.setCancelHandler { close(fd) }
        source?.resume()
    }

    // MARK: - Scan & process

    private func scanAlerts() {
        let fm = FileManager.default
        let dir = DirectorySetup.alertsDir
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsSubdirectoryDescendants
        ) else { return }

        let alertFiles = files.filter {
            $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("alert_")
        }
        guard !alertFiles.isEmpty else { return }

        for url in alertFiles {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? JSONDecoder().decode(PulseAlertPayload.self, from: data)
            else {
                moveToProcessed(url)
                continue
            }

            // Skip expired
            if let exp = payload.expireAt, exp < Date().timeIntervalSince1970 {
                moveToProcessed(url)
                continue
            }

            // Skip duplicates
            guard !seenIDs.contains(payload.id) else {
                moveToProcessed(url)
                continue
            }
            seenIDs.insert(payload.id)
            moveToProcessed(url)

            let notif = payload.toNotchNotification()
            DispatchQueue.main.async {
                NotchState.shared.enqueue(notif)
            }
        }
    }

    private func moveToProcessed(_ url: URL) {
        let dest = DirectorySetup.alertsProcessed
            .appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.moveItem(at: url, to: dest)
    }
}

// MARK: - PulseAlertPayload (mirrors Rust AlertPayload struct)

private struct PulseAlertPayload: Decodable {
    let id: String
    let title: String
    let subtitle: String
    let type: String
    let taskId: String?
    let priority: Double
    let leftAction: String
    let rightAction: String
    let expireAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, priority
        case taskId      = "task_id"
        case leftAction  = "left_action"
        case rightAction = "right_action"
        case expireAt    = "expire_at"
    }

    func toNotchNotification() -> NotchNotification {
        let notifType: NotifType = {
            switch type {
            case "meal":      return .meal
            case "class":     return .class_
            case "exercise":  return .exercise
            case "deadline":  return .deadline
            case "break":     return .break_
            case "lazy":      return .lazy
            case "task":      return .task
            default:          return .other
            }
        }()
        var notif = NotchNotification(
            title: title,
            subtitle: subtitle,
            type: notifType
        )
        notif.leftAction  = leftAction
        notif.rightAction = rightAction
        return notif
    }
}
