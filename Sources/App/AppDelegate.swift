import AppKit
import SwiftUI

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

        // Morning Briefing — lid open / wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
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

        // Phase D2: Rust Pulse bridge (reads world_state_canonical.json)
        WorldStateReader.shared.start()

        // Phase D3: IPC Bridge for Python brain (chat + commands)
        BridgeWatcher.shared.start()

        // Phase D4: Task store from Python brain
        TaskStore.shared.start()

        // Phase D5: Alert watcher (reads ~/notchly/v2/alerts/*.json → Stage 1A)
        AlertWatcher.shared.start()

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
            let state = NotchState.shared
            withAnimation(.spring(response: 0.50, dampingFraction: 0.88)) {
                state.rawProgress     = 1.0
                state.displayProgress = 1.0
                state.scrollProgress  = 1.0
            }
            state.transition(to: .s4_chat, spring: Springs.expand)
        }
    }

    @objc private func systemDidWake() {
        MorningGate.shared.markLidOpened()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            MorningGate.shared.checkMorningBriefing()
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
