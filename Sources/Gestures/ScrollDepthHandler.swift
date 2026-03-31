import AppKit
import Foundation

// Scroll depth → stage snap thresholds (vertical δ accumulated)
// δy   0– 20pt: dead zone — no stage change
// δy  20– 50pt: snap to s1_5_hover
// δy  50–120pt: snap to s2a_nowcard
// δy >120pt:    snap to s3_dashboard
// All snaps use pillSpring spring(0.42, 0.68)
// Scroll UP (δy negative) from any expanded stage → collapse to s0
class ScrollDepthHandler {
    static let shared = ScrollDepthHandler()
    private init() {}

    private var globalMonitor: Any?
    private var accumulator: CGFloat = 0
    private var gestureStartTime: Date = Date()

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        guard HoverZoneMonitor.shared.cursorInHoverZone() else { return }

        let phase = event.phase

        if phase == .began {
            accumulator = 0
            gestureStartTime = Date()
        }

        // Trackpad vs mouse wheel
        var delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            delta = event.scrollingDeltaY      // trackpad: use as-is
        } else {
            delta = event.scrollingDeltaY * 8  // mouse wheel: ×8
        }

        if phase == .changed || (!event.hasPreciseScrollingDeltas) {
            accumulator += delta
        }

        let abs = Swift.abs(accumulator)
        let state = NotchState.shared

        // Scroll UP → collapse from any expanded stage
        if accumulator < -20 {
            DispatchQueue.main.async {
                if state.stage != .s0_idle && state.stage != .s1a_notification
                    && state.stage != .s1b_timer {
                    state.transition(to: .s0_idle,
                                     spring: .spring(response: 0.35, dampingFraction: 0.80))
                }
            }
            return
        }

        // Stage snap based on accumulated depth
        let targetStage: NotchStage?
        switch abs {
        case 0..<20:   targetStage = nil          // dead zone
        case 20..<50:  targetStage = .s1_5_hover
        case 50..<120: targetStage = .s2a_nowcard
        default:       targetStage = .s3_dashboard
        }

        guard let target = targetStage else { return }

        DispatchQueue.main.async {
            guard state.stage != target else { return }
            // Don't override active notification (S1A/S1B owns notch)
            if state.stage == .s1a_notification || state.stage == .s1b_timer {
                if target == .s3_dashboard || target == .s2a_nowcard {
                    // Allow override to expand further
                    state.transition(to: target, spring: Springs.pill)
                }
                return
            }
            state.transition(to: target, spring: Springs.pill)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        if phase == .ended || phase == .cancelled {
            accumulator = 0
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}
