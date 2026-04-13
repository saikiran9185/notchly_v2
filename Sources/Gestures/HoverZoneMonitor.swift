import AppKit
import SwiftUI
import Foundation

class HoverZoneMonitor {
    static let shared = HoverZoneMonitor()
    private init() {}

    private var globalMonitor: Any?
    private var safetyTimer: Timer?
    private(set) var hoverInfluence: CGFloat = 0

    func start() {
        // NSEvent monitors fire on main thread — no dispatch needed
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.updateHoverState()
        }

        // Safety poll every 100ms — catches exits that mouseMoved misses
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateHoverState()
        }
        RunLoop.main.add(safetyTimer!, forMode: .common)
    }

    // Narrow trigger zone at the top — used to initiate hover from idle (85pt tall, 450pt wide)
    func cursorInHoverZone() -> Bool {
        let dims = NotchDimensions.shared
        let cursor = NSEvent.mouseLocation
        let zoneRect = NSRect(
            x: dims.screenMidX - 225,
            y: dims.screenMaxY - 85,
            width: 450,
            height: 85
        )
        return zoneRect.contains(cursor)
    }

    // Full pill zone — matches the actual rendered pill size at current displayProgress.
    // Used to keep expanded stages alive and allow scroll-back from inside the pill.
    func cursorInPillZone() -> Bool {
        let dims   = NotchDimensions.shared
        let state  = NotchState.shared
        let layout = NotchlyLayout(progress: state.displayProgress)
        let cursor = NSEvent.mouseLocation
        // Add 24pt horizontal margin + 20pt below to absorb cursor wobble
        let zoneRect = NSRect(
            x: dims.screenMidX - layout.width / 2 - 24,
            y: dims.screenMaxY - layout.height - 20,
            width: layout.width + 48,
            height: layout.height + 20
        )
        return zoneRect.contains(cursor)
    }

    func cursorInNotchZone() -> Bool {
        let dims = NotchDimensions.shared
        let cursor = NSEvent.mouseLocation
        let zoneRect = NSRect(
            x: dims.screenMidX - (dims.notchW / 2 + 10),
            y: dims.screenMaxY - (dims.notchH + 10),
            width: dims.notchW + 20,
            height: dims.notchH + 10
        )
        return zoneRect.contains(cursor)
    }

    // Called on main thread — always. No dispatch needed.
    private func updateHoverState() {
        let inTriggerZone = cursorInHoverZone()
        let inPillZone    = cursorInPillZone()
        let inAnyZone     = inTriggerZone || inPillZone

        hoverInfluence = inTriggerZone ? 1.0 : 0.0

        let state = NotchState.shared

        if inTriggerZone && state.stage == .s0_idle {
            state.transitionWith(stage: .s1_5_hover, progress: 0.12)
            return
        }

        // BUG-24 fix: only collapse when cursor leaves the full pill area, not just the
        // narrow 85pt trigger zone — prevents premature collapse on expanded stages
        guard !inAnyZone else { return }

        switch state.stage {
        case .s1_5_hover, .s1_5x_diagnosis,
             .s2a_nowcard, .s2b_missed,
             .s3_dashboard:
            state.collapse()
        default:
            break
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        safetyTimer?.invalidate()
    }
}
