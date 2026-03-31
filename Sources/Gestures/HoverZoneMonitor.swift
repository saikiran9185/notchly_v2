import AppKit
import Foundation

// Hover zone: w=400pt h=75pt centered at screenMidX, top at screen.maxY-75pt
// All gestures (scroll, swipe) captured only inside this zone.
// Exception: global hotkeys work from anywhere.
class HoverZoneMonitor {
    static let shared = HoverZoneMonitor()
    private init() {}

    private var globalMonitor: Any?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.updateHoverState()
        }
    }

    func cursorInHoverZone() -> Bool {
        let dims = NotchDimensions.shared
        let cursor = NSEvent.mouseLocation
        let zoneRect = NSRect(
            x: dims.screenMidX - 200,
            y: dims.screenMaxY - 75,
            width: 400,
            height: 75
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

    private func updateHoverState() {
        let inZone = cursorInHoverZone()
        DispatchQueue.main.async {
            let state = NotchState.shared
            if inZone && state.stage == .s0_idle {
                state.transition(to: .s1_5_hover, spring: Springs.hoverExpand)
            } else if !inZone && state.stage == .s1_5_hover {
                state.collapse()
            } else if !inZone && state.stage == .s2a_nowcard {
                state.collapse()
            } else if !inZone && state.stage == .s2b_missed {
                state.collapse()
            }
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}
