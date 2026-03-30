import AppKit
import Combine

/// Watches frontmost app changes and idle time.
final class AppWatcher {

    static let shared = AppWatcher()

    private var workspaceObservers: [NSObjectProtocol] = []
    private var idleTimer: Timer?
    private var lastEventTime: Date = Date()
    private(set) var idleMinutes: Int = 0

    var onFrontmostChange: ((String) -> Void)?
    var onIdleUpdate: ((Int) -> Void)?

    // Deep work: same app open ≥ 20 min
    private var appSwitchTimes: [String: Date] = [:]
    private(set) var currentDeepWorkApp: String?

    private init() {}

    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        let activated = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier else { return }
            self?.handleActivation(bundleID: bid)
        }

        workspaceObservers = [activated]

        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    func stop() {
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        idleTimer?.invalidate()
    }

    func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    // MARK: - Private

    private func handleActivation(bundleID: String) {
        lastEventTime = Date()
        appSwitchTimes[bundleID] = Date()
        onFrontmostChange?(bundleID)

        // Deep work check — if been on same app ≥ 20min
        let stayDuration = appSwitchTimes.compactMap { (k, v) -> TimeInterval? in
            k == bundleID ? Date().timeIntervalSince(v) : nil
        }.first ?? 0

        currentDeepWorkApp = stayDuration >= 20 * 60 ? bundleID : nil
        NotchState.shared.context.isDeepWork = currentDeepWorkApp != nil
    }

    private func checkIdle() {
        let secs = Int(Date().timeIntervalSince(lastEventTime))
        idleMinutes = secs / 60
        onIdleUpdate?(idleMinutes)
    }
}
