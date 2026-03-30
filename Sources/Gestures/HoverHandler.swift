import AppKit
import SwiftUI

/// Tracks mouse enter/exit over the notch pill and fires S1.5 hover.
/// 300ms debounce on enter to prevent micro-hovers.
final class HoverHandler {

    static let shared = HoverHandler()
    private var enterTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3

    private init() {}

    func mouseEntered() {
        enterTimer?.invalidate()
        enterTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            DispatchQueue.main.async {
                let state = NotchState.shared
                if state.stage == .s0_idle {
                    state.transition(to: .s1_5_hover)
                }
            }
        }
    }

    func mouseExited() {
        enterTimer?.invalidate()
        DispatchQueue.main.async {
            let state = NotchState.shared
            if state.stage == .s1_5_hover {
                state.collapseToIdle()
            }
        }
    }
}
