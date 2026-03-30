import AppKit
import SwiftUI

// MARK: - Swipe action

enum SwipeAction {
    case accept      // right → accept / done
    case dismiss     // left  → dismiss / skip
    case snooze5     // up    → snooze 5 min
    case expand      // down  → expand to dashboard
}

// MARK: - SwipeHandler

/// Translates NSTrackingArea / NSEvent swipes into NotchState updates.
/// All thresholds from the spec:
///   trigger  = 44 pt
///   elastic  = 0.4 damping (spring)
///   velocity = 200 pt/s to auto-complete
final class SwipeHandler {

    static let shared = SwipeHandler()

    private let triggerPt: CGFloat     = 44.0
    private let velocityThreshold: CGFloat = 200.0

    weak var state: NotchState? = NotchState.shared

    private init() {}

    // MARK: - Swipe X (left / right) with real-time rubber-band

    func handleDrag(translation: CGFloat, velocity: CGFloat) {
        guard let state = state else { return }

        // Rubber-band: offset = translation × 0.4
        let damped = translation * 0.4
        DispatchQueue.main.async {
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                state.swipeXOffset = damped
            }
        }

        // Wash colors
        let pct = min(1.0, abs(translation) / triggerPt)
        DispatchQueue.main.async {
            state.swipeGreenWashOpacity = translation > 0 ? pct * 0.25 : 0
            state.swipeGrayWashOpacity  = translation < 0 ? pct * 0.25 : 0
        }

        // Button scale: 1.0 → 1.15 at trigger
        let scale = 1.0 + 0.15 * min(1.0, pct)
        DispatchQueue.main.async {
            if translation > 0 { state.swipeRightBtnScale = scale }
            else               { state.swipeLeftBtnScale  = scale }
        }
    }

    func handleDragEnded(translation: CGFloat, velocity: CGFloat) {
        let shouldComplete = abs(translation) >= triggerPt || abs(velocity) >= velocityThreshold
        if shouldComplete {
            commitSwipe(translation > 0 ? .accept : .dismiss)
        } else {
            cancelSwipe()
        }
    }

    func handleVerticalSwipe(translation: CGFloat, velocity: CGFloat) {
        guard abs(translation) >= triggerPt || abs(velocity) >= velocityThreshold else { return }
        if translation > 0 {
            commitSwipe(.expand)
        } else {
            commitSwipe(.snooze5)
        }
    }

    // MARK: - Commit / Cancel

    private func commitSwipe(_ action: SwipeAction) {
        guard let state = state else { return }

        // Haptic-equivalent: play NSSound if wanted
        // NSSound(named: "Tink")?.play()

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                state.swipeXOffset        = 0
                state.swipeGreenWashOpacity = 0
                state.swipeGrayWashOpacity  = 0
                state.swipeRightBtnScale  = 1.0
                state.swipeLeftBtnScale   = 1.0
            }
        }

        switch action {
        case .accept:   ActionEngine.shared.acceptCurrentAlert()
        case .dismiss:  ActionEngine.shared.dismissCurrentAlert()
        case .snooze5:  ActionEngine.shared.snoozeCurrentAlert(minutes: 5)
        case .expand:   state.transition(to: .s3_dashboard)
        }
    }

    private func cancelSwipe() {
        guard let state = state else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                state.swipeXOffset        = 0
                state.swipeGreenWashOpacity = 0
                state.swipeGrayWashOpacity  = 0
                state.swipeRightBtnScale  = 1.0
                state.swipeLeftBtnScale   = 1.0
            }
        }
    }
}
