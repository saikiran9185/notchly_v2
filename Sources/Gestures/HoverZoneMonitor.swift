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
        let inZone = cursorInHoverZone()
        hoverInfluence = inZone ? 1.0 : 0.0

        guard !inZone else { return }

        let state = NotchState.shared
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
