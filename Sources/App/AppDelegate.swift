import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Phase A: create directories and seed files
        DirectorySetup.createAll()

        // Phase A: cache notch dimensions once from actual screen
        NotchDimensions.shared.recalculate()

        // Create and show the notch panel
        windowController = NotchWindowController()
        windowController?.showWindow(nil)

        // Watch for screen layout changes (external monitor, lid close/open, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Phase B: request calendar access early
        CalendarReader.shared.requestAccess { _ in }

        // Phase C: data sources (AppFocusMonitor + IdleDetector initialize in their own setup/init)
        ContextEngine.shared.start()
        FSEventWatcher.shared.start()
        _ = AppFocusMonitor.shared   // triggers setup() in init
        _ = IdleDetector.shared      // passive detector, no start needed

        // Phase D: gesture system
        HoverZoneMonitor.shared.start()
        ScrollDepthHandler.shared.start()
        SwipeGestureHandler.shared.start()

        // Phase E: hotkeys
        HotKeyManager.shared.register()

        // Phase F: learning + memory
        WeeklyRebuilder.shared.start()
        WorkingMemory.shared.scheduleMidnightReset()

        // Phase G: cognitive engine
        BDIAgent.shared.initialize()

        // Onboarding: show permission flow on first launch
        if !UserDefaults.standard.bool(forKey: "notchly_setup_complete") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotchState.shared.transition(to: .s4_chat)
        }
    }

    @objc private func screenParametersChanged() {
        NotchDimensions.shared.recalculate()
        windowController?.repositionWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // LSUIElement app — never quit on window close
    }
}
