import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Setup file directories
        DirectorySetup.createAll()

        // Check first launch
        if !UserDefaults.standard.bool(forKey: "notchly_setup_complete") {
            // Will show onboarding via NotchState in root view
        }

        // Start data sources
        CalendarWatcher.shared.start()
        AppWatcher.shared.start()
        AlertScheduler.shared.start()
        BDIAgent.shared.initialize()

        // Wire app watcher → state
        AppWatcher.shared.onFrontmostChange = { bundle in
            DispatchQueue.main.async {
                NotchState.shared.context.frontmostApp = bundle
                NotchState.shared.context.runningApps  = AppWatcher.shared.runningBundleIDs()
            }
        }
        AppWatcher.shared.onIdleUpdate = { minutes in
            DispatchQueue.main.async {
                NotchState.shared.context.idleMinutes = minutes
            }
        }

        // Wire calendar watcher → state
        CalendarWatcher.shared.onEventChange = { _ in
            DispatchQueue.main.async {
                NotchState.shared.context.energyLevel =
                    EnergyModel.shared.energyLevel(at: Calendar.current.component(.hour, from: Date()))
            }
        }

        // Create and show the notch window
        windowController = NotchWindowController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
