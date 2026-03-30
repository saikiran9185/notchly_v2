import AppKit
import SwiftUI

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

        // Phase B — gesture system
        HoverZoneMonitor.shared.start()
        ScrollDepthHandler.shared.start()
        SwipeGestureHandler.shared.start()
        DoubleClickHandler.shared.start()
        HotKeyManager.shared.register()

        // Wire hover zone → stage transitions
        HoverZoneMonitor.shared.onEnter = {
            DispatchQueue.main.async {
                let s = NotchState.shared
                if s.stage == .s0_idle {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        s.stage = .s1_5_hover
                    }
                }
            }
        }
        HoverZoneMonitor.shared.onExit = {
            DispatchQueue.main.async {
                let s = NotchState.shared
                if s.stage == .s1_5_hover {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        s.stage = .s0_idle
                    }
                }
                // Auto-dismiss S2A/S2B on mouse-away (immediate, no grace)
                if s.stage == .s2a_nowcard || s.stage == .s2b_missed {
                    withAnimation(.easeOut(duration: 0.25)) {
                        s.stage = .s0_idle
                    }
                }
                // Auto-dismiss S3 on mouse-away (immediate)
                if s.stage == .s3_dashboard {
                    withAnimation(.easeOut(duration: 0.25)) {
                        s.stage = .s0_idle
                    }
                }
            }
        }

        // Create and show the notch window
        windowController = NotchWindowController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
