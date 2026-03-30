import AppKit
import SwiftUI

/// Captures two-finger scroll events over the hover zone and maps
/// accumulated vertical delta to stage thresholds.
///
/// Thresholds (spec Part 7):
///   δy   0– 20pt  dead zone
///   δy  20– 50pt  → s1_5_hover
///   δy  50–120pt  → s2a_nowcard
///   δy >120pt     → s3_dashboard
///   scroll UP     → collapse to s0
final class ScrollDepthHandler {

    static let shared = ScrollDepthHandler()

    private var globalMonitor: Any?
    private var accumulator: CGFloat = 0
    private var lastPhase: NSEvent.Phase = []
    private var currentStageFromScroll: NotchStage = .s0_idle

    private init() {}

    // MARK: - Start / Stop

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
    }

    // MARK: - Event handling

    private func handle(_ event: NSEvent) {
        guard HoverZoneMonitor.shared.cursorInHoverZone() else { return }

        // Reset accumulator on new gesture
        if event.phase.contains(.began) {
            accumulator = 0
            currentStageFromScroll = NotchState.shared.stage
        }

        // Scale mouse wheel to match trackpad feel
        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            delta = event.scrollingDeltaY
        } else {
            delta = event.scrollingDeltaY * 8
        }

        if event.phase.contains(.changed) || (!event.hasPreciseScrollingDeltas && event.phase == []) {
            accumulator += delta
        }

        // Scroll UP — collapse from any expanded stage
        if accumulator < -20 {
            snap(to: .s0_idle)
            return
        }

        // Scroll DOWN — stage snaps
        let target = stageForAccumulator(accumulator)

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            snap(to: target)
            accumulator = 0
        } else {
            // Live preview during gesture
            if target != NotchState.shared.stage {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                        NotchState.shared.stage = target
                    }
                }
            }
        }
    }

    private func stageForAccumulator(_ acc: CGFloat) -> NotchStage {
        switch acc {
        case ..<20:    return .s0_idle
        case 20..<50:  return .s1_5_hover
        case 50..<120: return .s2a_nowcard
        default:       return .s3_dashboard
        }
    }

    private func snap(to stage: NotchStage) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                NotchState.shared.stage = stage
            }
        }
    }
}
