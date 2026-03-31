import SwiftUI
import AppKit

// Full swipe physics state machine wrapper.
// Wraps swipeable content (Stage 1A) with 4-state physics:
// STATE 0: Entrance + affordance
// STATE 1: Pull (|δx| 1–39pt) — tracking with friction
// STATE 2: Threshold (|δx| ≥ 40pt) — color snap + button morph
// STATE 3A: Snap back (released before threshold)
// STATE 3B: Suck into notch (released at/past threshold)
struct SwipeCardView<Content: View>: View {
    @EnvironmentObject var state: NotchState
    @ViewBuilder var content: () -> Content

    @State private var xOffset: CGFloat = 0
    @State private var swipeRatio: Double = 0     // 0.0→1.0
    @State private var direction: SwipeDir = .none
    @State private var passedThreshold: Bool = false

    private let threshold: CGFloat = 40.0

    var body: some View {
        ZStack {
            // Color wash overlays
            if direction == .right && swipeRatio > 0 {
                RoundedRectangle(cornerRadius: 14)
                    .fill(NT.swipeRightWash(swipeRatio))
                    .allowsHitTesting(false)
            } else if direction == .left && swipeRatio > 0 {
                RoundedRectangle(cornerRadius: 14)
                    .fill(NT.swipeLeftWash(swipeRatio))
                    .allowsHitTesting(false)
            }

            content()
        }
        .offset(x: xOffset * 0.90)    // 90% tracking = friction
        .onChange(of: state.swipeXOffset) { delta in
            updatePhysics(delta: delta)
        }
        .onChange(of: state.swipePhase) { phase in
            if phase == .committed { commitSwipe() }
            if phase == .idle      { snapBack() }
        }
    }

    private func updatePhysics(delta: CGFloat) {
        let abs = Swift.abs(delta)
        swipeRatio = min(1.0, abs / threshold)
        direction = delta > 0 ? .right : delta < 0 ? .left : .none
        passedThreshold = abs >= threshold

        withAnimation(.linear(duration: 0)) {
            xOffset = delta
        }

        if passedThreshold {
            // Snap color wash to full opacity
            withAnimation(.easeInOut(duration: 0.12)) {
                swipeRatio = 1.0
            }
            // Haptic on first threshold cross
            NSHapticFeedbackManager.defaultPerformer
                .perform(.levelChange, performanceTime: .now)
        }
    }

    // STATE 3A — Snap back
    private func snapBack() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
            xOffset = 0
        }
        withAnimation(.easeOut(duration: 0.20)) {
            swipeRatio = 0
        }
        direction = .none
        passedThreshold = false
    }

    // STATE 3B — Suck into notch
    private func commitSwipe() {
        // Action fires immediately (before animation)
        if direction == .right {
            state.currentNotification.map { notif in
                EpisodicLog.shared.append(action: "swipe_right", notification: notif, context: state.context)
                EVRUpdater.shared.recordPrimary(for: notif)
            }
            let msg = state.currentTask.map { "\($0.title) done · loading" } ?? "Done"
            state.showContinuity(msg)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        } else if direction == .left {
            state.currentNotification.map { notif in
                EpisodicLog.shared.append(action: "swipe_left", notification: notif, context: state.context)
                EVRUpdater.shared.recordDismissed(for: notif)
            }
            state.showContinuity("Skipped · loading")
        }

        // Suck-into-notch animation simultaneously
        withAnimation(.easeIn(duration: 0.22)) {
            xOffset = 0
        }

        // Notch edge pulse then collapse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            state.dismissCurrentNotification()
        }
    }
}

enum SwipeDir { case none, left, right }
