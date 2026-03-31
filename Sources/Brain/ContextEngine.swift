import Foundation
import EventKit

// Rebuilds ContextSnapshot every 60 seconds.
// Also triggers on: any user action, wake from sleep, app switch.
class ContextEngine {
    static let shared = ContextEngine()
    private init() {}

    private var contextTimer: Timer?
    private var retryQueue: [RetryEntry] = []
    private var retryTimer: Timer?

    func start() {
        rebuildContext()
        contextTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.rebuildContext()
        }
        RunLoop.main.add(contextTimer!, forMode: .common)

        // Retry queue — check every 5min
        retryTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.processRetryQueue()
        }
    }

    func rebuildNow() {
        rebuildContext()
    }

    private func rebuildContext() {
        let state = NotchState.shared
        var snap = ContextSnapshot()

        snap.hour = Calendar.current.component(.hour, from: Date())
        snap.energyLevel = EnergyModel.shared.currentEnergy(
            at: snap.hour,
            profile: SemanticProfile.shared.current
        )
        snap.frontmostApp = AppFocusMonitor.shared.frontmostBundleID
        snap.runningApps  = AppFocusMonitor.shared.runningBundleIDs
        snap.idleMinutes  = Int(IdleDetector.shared.idleSeconds() / 60)
        snap.isDeepWork   = AppFocusMonitor.shared.isDeepWork
        snap.isInClass    = CalendarReader.shared.isCurrentlyInClass()
        snap.missedCount  = state.missedNotifications.count
        snap.dayProgress  = dayProgress()

        // Suggest app if task has a known bundle ID
        if let task = state.currentTask, let bundleID = task.relatedAppBundleID {
            let isRunning = snap.runningApps.contains(bundleID)
            let isFront   = snap.frontmostApp == bundleID
            snap.suggestedApp = AppLaunchHint(
                bundleID: bundleID,
                displayName: appDisplayName(bundleID),
                isRunning: isRunning,
                isFrontmost: isFront
            )
        }

        DispatchQueue.main.async {
            state.context = snap
            state.isDeepFocus = snap.isDeepWork
            state.isClassMode = snap.isInClass

            // Rebuild P scores with new context
            let scored = PriorityScorer.shared.scoreAll(state.taskQueue, context: snap)
            state.taskQueue = scored
        }
    }

    private func dayProgress() -> Double {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    private func processRetryQueue() {
        let now = Date()
        let pending = retryQueue.filter { $0.nextRetry <= now && $0.retryCount < 6 }
        for entry in pending {
            let profile = SemanticProfile.shared.current
            let shouldFire = InterruptionGuard.shared.shouldFire(
                entry.notification, task: entry.task,
                context: NotchState.shared.context, profile: profile)
            if shouldFire {
                DispatchQueue.main.async {
                    NotchState.shared.enqueue(entry.notification)
                }
            }
        }
        retryQueue.removeAll { $0.retryCount >= 6 || $0.nextRetry <= now }
    }

    deinit {
        contextTimer?.invalidate()
        retryTimer?.invalidate()
    }

    // App display name map
    private let appNames: [String: String] = [
        "org.blender.Blender":          "Blender",
        "com.figma.Desktop":            "Figma",
        "com.apple.dt.Xcode":           "Xcode",
        "notion.id":                    "Notion",
        "com.apple.Terminal":           "Terminal",
        "com.anthropic.claudefordesktop": "Claude",
        "com.adobe.premierepro":        "Premiere",
        "com.adobe.aftereffects":       "After Effects",
        "com.adobe.photoshop":          "Photoshop",
        "com.adobe.illustrator":        "Illustrator",
        "com.microsoft.VSCode":         "VS Code",
        "com.blackmagicdesign.resolve": "DaVinci",
        "com.google.Chrome":            "Chrome"
    ]

    func appDisplayName(_ bundleID: String) -> String {
        appNames[bundleID] ?? bundleID.components(separatedBy: ".").last ?? bundleID
    }
}
