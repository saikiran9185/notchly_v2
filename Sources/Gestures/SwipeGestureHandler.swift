import AppKit
import Foundation

// Horizontal swipe → action commitment
// AVAILABLE: s1a, s1b, s2a, s2b (wherever buttons visible)
// NOT available: s1_5, s3, s4, s0 → horizontal = macOS default
// COMMIT: abs(xAccum) ≥ 40pt AND velocity > 200pt/s
class SwipeGestureHandler {
    static let shared = SwipeGestureHandler()
    private init() {}

    private var globalMonitor: Any?
    private var doubleClickMonitor: Any?   // BUG-1 fix: stored so it can be removed on deinit
    private var xAccumulator: CGFloat = 0
    private var gestureStartTime: Date = Date()

    private let commitThreshold: CGFloat = 40.0
    private let velocityThreshold: CGFloat = 200.0

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event)
        }
        setupDoubleClickMonitor()   // BUG-1 fix: was defined but never called
    }

    private func handle(_ event: NSEvent) {
        guard HoverZoneMonitor.shared.cursorInHoverZone() else { return }

        let state = NotchState.shared
        let swipeableStages: [NotchStage] = [.s1a_notification, .s1b_timer,
                                              .s2a_nowcard, .s2b_missed]
        guard swipeableStages.contains(state.stage) else { return }

        // Determine if horizontal swipe (x dominant)
        let dx = Swift.abs(event.scrollingDeltaX)
        let dy = Swift.abs(event.scrollingDeltaY)
        guard dx > dy else { return }   // vertical = scroll depth, not swipe

        let phase = event.phase
        if phase == .began {
            xAccumulator = 0
            gestureStartTime = Date()
        }

        let delta = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaX
            : event.scrollingDeltaX * 8

        xAccumulator += delta

        let absX = Swift.abs(xAccumulator)
        let ratio = min(1.0, Double(absX / commitThreshold))

        // Update physics state in NotchState for SwipeCardView rendering
        DispatchQueue.main.async {
            state.swipeXOffset = self.xAccumulator
            state.swipeRatio   = ratio
            state.swipePhase   = absX >= self.commitThreshold ? .threshold : .pulling
        }

        if phase == .ended || phase == .cancelled {
            let elapsed = Date().timeIntervalSince(gestureStartTime)
            let velocity = elapsed > 0 ? absX / CGFloat(elapsed) : 0

            let committed = absX >= commitThreshold && velocity > velocityThreshold
            DispatchQueue.main.async {
                if committed {
                    state.swipePhase = .committed
                } else {
                    // Snap back
                    state.swipePhase   = .idle
                    state.swipeXOffset = 0
                    state.swipeRatio   = 0
                }
            }
            xAccumulator = 0
        }
    }

    // Double-click on notch zone
    private func setupDoubleClickMonitor() {
        // BUG-2 fix: store reference so monitor can be removed on deinit
        doubleClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let _ = self,
                  HoverZoneMonitor.shared.cursorInNotchZone(),
                  event.clickCount == 2
            else { return }
            let state = NotchState.shared
            DispatchQueue.main.async {
                switch state.stage {
                case .s1a_notification:
                    // S1 owns notch — double-click = primary action, NOT S4
                    // Primary action handled by Stage1AView
                    break
                case .s1b_timer:
                    break  // S1B: timer primary action
                default:
                    state.transition(to: .s4_chat, spring: Springs.expand)
                }
            }
        }
    }

    deinit {
        if let m = globalMonitor    { NSEvent.removeMonitor(m) }
        if let m = doubleClickMonitor { NSEvent.removeMonitor(m) }
    }
}
