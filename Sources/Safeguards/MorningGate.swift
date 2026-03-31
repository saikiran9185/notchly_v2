import Foundation
import AppKit

// SAFEGUARD 4 — False Morning Gate
// Morning briefing ONLY fires if ALL THREE are true:
//   1. lid_open = true (NSWorkspace.didWakeNotification fired)
//   2. systemIdleSeconds() > 18000 (5 hours idle)
//   3. Calendar.current.component(.hour) >= 5 AND < 11
// If ANY false → no morning briefing, stay silent.
class MorningGate {
    static let shared = MorningGate()
    private init() {}

    private var lidJustOpened: Bool = false

    func markLidOpened() {
        lidJustOpened = true
    }

    func checkMorningBriefing() {
        let hour = Calendar.current.component(.hour, from: Date())
        let is5HoursIdle = IdleDetector.shared.is5HoursIdle

        guard lidJustOpened && is5HoursIdle && hour >= 5 && hour < 11 else {
            lidJustOpened = false
            return
        }
        lidJustOpened = false
        fireMorningBriefing(hour: hour)
    }

    private func fireMorningBriefing(hour: Int) {
        let state = NotchState.shared
        let message = morningMessage(hour: hour, state: state)
        let notif = NotchNotification(
            title: message,
            type: .other
        )
        DispatchQueue.main.async {
            state.enqueue(notif)
        }
    }

    private func morningMessage(hour: Int, state: NotchState) -> String {
        // Check for deadline first
        if let urgent = state.taskQueue.first(where: {
            guard let h = $0.hoursUntilDeadline else { return false }
            return h < 24
        }) {
            return "\(urgent.title) due today · \(hour < 9 ? "exercise first?" : "start now?")"
        }

        switch hour {
        case 5, 6: return "good morning · exercise window open · breakfast at 8:30"
        case 7, 8: return "late start · breakfast closing in 15m · \(state.leftToday) tasks today"
        case 9:    return "class soon · \(state.taskQueue.first?.title ?? "queue clear") first?"
        default:   return "morning's half gone · \(state.taskQueue.first?.title ?? "queue") is the priority"
        }
    }
}
