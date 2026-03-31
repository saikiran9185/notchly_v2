import AppKit
import Foundation

// Monitors frontmost app + running apps.
// Detects deep work: same app >20min + no switches.
class AppFocusMonitor {
    static let shared = AppFocusMonitor()
    private init() { setup() }

    private(set) var frontmostBundleID: String = ""
    private(set) var runningBundleIDs: Set<String> = []
    private(set) var isDeepWork: Bool = false

    private var lastSwitchTime: Date = Date()
    private var lastBundleID: String = ""
    private var deepWorkTimer: Timer?

    private func setup() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self,
                       selector: #selector(appActivated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(wakeFromSleep),
                       name: NSWorkspace.didWakeNotification,
                       object: nil)

        updateRunningApps()
        updateFrontmost()
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              let bid = app.bundleIdentifier
        else { return }

        let switched = bid != frontmostBundleID
        frontmostBundleID = bid
        updateRunningApps()

        if switched {
            lastSwitchTime = Date()
            lastBundleID = bid
            isDeepWork = false
            deepWorkTimer?.invalidate()
            // Start 20min deep work detection
            deepWorkTimer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: false) { [weak self] _ in
                guard let self = self, self.frontmostBundleID == bid else { return }
                self.isDeepWork = true
                ContextEngine.shared.rebuildNow()
            }
        }
    }

    @objc private func wakeFromSleep() {
        ContextEngine.shared.rebuildNow()
        MorningGate.shared.checkMorningBriefing()
    }

    private func updateRunningApps() {
        runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications
                .compactMap { $0.bundleIdentifier }
        )
    }

    private func updateFrontmost() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }

    deinit {
        deepWorkTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
