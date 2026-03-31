import Foundation

// SAFEGUARD 5 — Focus Mode
// User sets "back at [time]" via S4 or focus button.
// Pill: "focus · back at [time]"
// All non-urgent alerts silenced. Queue resumes exactly where left off.
class FocusMode {
    static let shared = FocusMode()
    private init() {}

    private var resumeTimer: Timer?

    func activate(until time: Date, state: NotchState) {
        state.isFocusMode = true
        state.focusModeEndTime = time

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        state.showContinuity("focus · back at \(fmt.string(from: time))")

        let delay = time.timeIntervalSinceNow
        guard delay > 0 else { deactivate(state: state); return }

        resumeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.deactivate(state: state)
        }
    }

    func deactivate(state: NotchState) {
        state.isFocusMode = false
        state.focusModeEndTime = nil
        state.showContinuity("Focus ended · queue resuming")
        ContextEngine.shared.rebuildNow()
    }

    deinit { resumeTimer?.invalidate() }
}
