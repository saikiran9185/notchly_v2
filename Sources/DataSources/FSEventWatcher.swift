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
                    }
                } else {
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
