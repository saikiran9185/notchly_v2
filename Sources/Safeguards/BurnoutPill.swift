import Foundation

// SAFEGUARD 3 — Burnout Hard-Line Pill
// Trigger: AI detects burnout risk (too many hours, late night + deep work)
// Appearance: 40pt lower drop + INVERTED colors (red bg, light text) + HORIZONTAL buttons
// Distinct from diagnosis mode (gray+vertical vs red+horizontal)
class BurnoutPill {
    static let shared = BurnoutPill()
    private init() {}

    // Detect burnout risk:
    // - Current time is late (after 22:00) AND
    // - User has been in deep work >2h AND
    // - No break taken in 3h
    func checkBurnoutRisk(context: ContextSnapshot) -> Bool {
        guard !GlassBreak.shared.isActive else { return false }
        let hour = context.hour
        guard hour >= 22 || hour < 4 else { return false }
        guard context.isDeepWork else { return false }
        return true
    }

    func fire(state: NotchState) {
        let notif = NotchNotification(
            title: "Working very late — take a break",
            subtitle: "Option-hold for deadline mode",
            type: .break_,
            leftAction: "5 More Min",
            centerAction: "Dismiss",
            rightAction: "Take break now"
        )
        // Burnout pill uses a special flag — UI shows inverted red pill + horizontal buttons
        // at 40pt lower position. See BurnoutPillView (rendered via DiagnosisPillView variant)
        state.enqueue(notif)
    }
}

// Extension on NotchNotification to mark burnout
extension NotchNotification {
    init(title: String, subtitle: String = "", type: NotifType,
         leftAction: String, centerAction: String, rightAction: String) {
        self.id           = UUID()
        self.title        = title
        self.subtitle     = subtitle
        self.type         = type
        self.leftAction   = leftAction
        self.centerAction = centerAction
        self.rightAction  = rightAction
    }
}
