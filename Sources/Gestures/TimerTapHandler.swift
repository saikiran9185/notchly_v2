import AppKit
import SwiftUI

/// Manages the countdown timer for S1B and handles tap-to-pause/resume.
/// All timers stored in vars and invalidated in deinit (BUG 1 fix).
final class TimerTapHandler {

    static let shared = TimerTapHandler()

    private var countdownTimer: Timer?

    private init() {}

    deinit {
        countdownTimer?.invalidate()
    }

    // MARK: - Start / Stop / Pause

    func startTimer(seconds: Int, taskName: String) {
        countdownTimer?.invalidate()
        let s = NotchState.shared
        s.timerSecondsRemaining = seconds
        s.timerTaskName        = taskName
        s.timerIsPaused        = false

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                NotchState.shared.stage = .s1b_timer
            }
        }
    }

    func togglePause() {
        let s = NotchState.shared
        if s.timerIsPaused {
            // Resume
            s.timerIsPaused = false
            let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(t, forMode: .common)
            countdownTimer = t
        } else {
            // Pause
            countdownTimer?.invalidate()
            countdownTimer = nil
            s.timerIsPaused = true
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    func stopTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        let s = NotchState.shared
        s.timerSecondsRemaining = 0
        s.timerTaskName        = ""
        s.timerIsPaused        = false
    }

    // MARK: - Formatted display string

    func displayString(seconds: Int) -> String {
        if seconds > 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return "\(h)h \(m)m"
        } else {
            let m = seconds / 60
            let s = seconds % 60
            return String(format: "%d:%02d", m, s)
        }
    }

    // MARK: - Private

    private func tick() {
        let s = NotchState.shared
        guard s.timerSecondsRemaining > 0 else {
            timeUp()
            return
        }
        s.timerSecondsRemaining -= 1
    }

    private func timeUp() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        let s = NotchState.shared
        s.timerSecondsRemaining = 0
        s.showBanner("\(s.timerTaskName) — time's up")
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
