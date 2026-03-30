import AppKit
import SwiftUI

/// Full swipe physics state machine (spec Part 7).
///
/// STATE 0 — entrance / affordance nudge (once per install)
/// STATE 1 — pull (|δx| 1–39pt):  rubber-band 90%, color wash builds, button scales
/// STATE 2 — threshold (|δx| ≥40pt): wash snaps to full, button text morphs, haptic
/// STATE 3A — snap back (released before threshold)
/// STATE 3B — suck into notch (released at/past threshold)
final class SwipeGestureHandler {

    static let shared = SwipeGestureHandler()

    private var globalMonitor: Any?
    private var xAccum: CGFloat = 0
    private var gestureStart: Date = Date()
    private let triggerPt: CGFloat = 40
    private let velocityThreshold: CGFloat = 200

    private init() {}

    // MARK: - Start / Stop

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
        }
        playAffordanceNudgeIfNeeded()
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
    }

    // MARK: - Event handling

    private func handle(_ event: NSEvent) {
        guard HoverZoneMonitor.shared.cursorInHoverZone() else { return }

        // Only handle horizontal-dominant scroll in S1a / S1b / S2a / S2b
        let stage = NotchState.shared.stage
        guard [.s1a_notification, .s1b_timer, .s2a_nowcard, .s2b_missed].contains(stage) else { return }

        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.scrollingDeltaX * 8
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 8

        // Ignore vertical-dominant scrolls (let ScrollDepthHandler handle them)
        guard abs(dx) > abs(dy) else { return }

        if event.phase.contains(.began) {
            xAccum = 0
            gestureStart = Date()
        }

        if event.phase.contains(.changed) || event.phase == [] {
            xAccum += dx
            updateState1(xAccum: xAccum)

            // Cross into threshold
            if abs(xAccum) >= triggerPt {
                updateState2(xAccum: xAccum)
            }
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            let elapsed = max(0.01, Date().timeIntervalSince(gestureStart))
            let velocity = abs(xAccum) / CGFloat(elapsed)
            let committed = abs(xAccum) >= triggerPt || velocity >= velocityThreshold

            if committed {
                fireState3B(direction: xAccum > 0 ? .right : .left)
            } else {
                fireState3A()
            }
            xAccum = 0
        }
    }

    // MARK: - Physics states

    /// STATE 1 — rubber band + wash builds
    private func updateState1(xAccum: CGFloat) {
        let ratio = min(1.0, abs(xAccum) / triggerPt)
        let offset = xAccum * 0.90

        DispatchQueue.main.async {
            let s = NotchState.shared
            withAnimation(.interactiveSpring(response: 0.20, dampingFraction: 0.95)) {
                s.swipeXOffset = offset
            }
            if xAccum > 0 {
                s.swipeGreenWashOpacity = ratio * 0.55
                s.swipeGrayWashOpacity  = 0
                s.swipeRightBtnScale    = 1.0 + ratio * 0.08
                s.swipeLeftBtnScale     = 1.0 - ratio * 0.80 + 0.20   // floor at 0.20
            } else {
                s.swipeGrayWashOpacity  = ratio * 0.40
                s.swipeGreenWashOpacity = 0
                s.swipeLeftBtnScale     = 1.0 + ratio * 0.08
                s.swipeRightBtnScale    = 1.0 - ratio * 0.80 + 0.20
            }
        }
    }

    /// STATE 2 — snap wash to full + haptic
    private func updateState2(xAccum: CGFloat) {
        DispatchQueue.main.async {
            let s = NotchState.shared
            withAnimation(.easeInOut(duration: 0.12)) {
                if xAccum > 0 {
                    s.swipeGreenWashOpacity = 0.55
                    s.swipeGrayWashOpacity  = 0
                } else {
                    s.swipeGrayWashOpacity  = 0.40
                    s.swipeGreenWashOpacity = 0
                }
            }
        }
        NSHapticFeedbackManager.defaultPerformer
            .perform(.levelChange, performanceTime: .now)
    }

    /// STATE 3A — snap back (below threshold)
    private func fireState3A() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                let s = NotchState.shared
                s.swipeXOffset        = 0
                s.swipeGreenWashOpacity = 0
                s.swipeGrayWashOpacity  = 0
                s.swipeRightBtnScale  = 1.0
                s.swipeLeftBtnScale   = 1.0
            }
        }
    }

    /// STATE 3B — suck into notch + fire action
    private func fireState3B(direction: SwipeDirection) {
        // Action fires IMMEDIATELY before animation
        switch direction {
        case .right: ActionEngine.shared.acceptCurrentAlert()
        case .left:  ActionEngine.shared.dismissCurrentAlert()
        }

        // Suck animation: translateY -notchH, scale 0.1, opacity 0 in 0.22s
        let notchH = NotchDimensions.shared.notchH
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.22)) {
                let s = NotchState.shared
                s.swipeXOffset        = 0
                s.swipeGreenWashOpacity = 0
                s.swipeGrayWashOpacity  = 0
                s.swipeRightBtnScale  = 1.0
                s.swipeLeftBtnScale   = 1.0
            }
        }

        // Notch edge pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // Continuity banner already shown by ActionEngine
        }

        NSHapticFeedbackManager.defaultPerformer
            .perform(.generic, performanceTime: .now)
    }

    // MARK: - Affordance nudge (fires once per install)

    private func playAffordanceNudgeIfNeeded() {
        guard !NotchState.shared.swipeHintShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.nudge()
        }
    }

    private func nudge() {
        let s = NotchState.shared
        // +10pt right
        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
            s.swipeXOffset = 10
        }
        // −10pt left after 0.28s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                s.swipeXOffset = -10
            }
        }
        // Return to 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                s.swipeXOffset = 0
            }
            s.swipeHintShown = true
        }
    }
}

enum SwipeDirection { case left, right }
