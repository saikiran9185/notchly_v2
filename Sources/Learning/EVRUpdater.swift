import Foundation

// LAYER 1 — EVR Updater: W confidence per notification type
// λ = 0.85 (memory decay)
// primary:   W = W×0.85 + 1.0×0.15
// secondary: W = W×0.85 + 0.5×0.15
// dismissed: W = W×0.85 + (−0.3)×0.15
// ignored:   W = W×0.85 + (−0.5)×0.15
class EVRUpdater {
    static let shared = EVRUpdater()
    private init() {}

    private let λ = 0.85

    func recordPrimary(for notif: NotchNotification) {
        updateW(notif: notif, signal: 1.0, delay: 0)
    }

    func recordSecondary(for notif: NotchNotification) {
        updateW(notif: notif, signal: 0.5, delay: 0)
    }

    func recordDismissed(for notif: NotchNotification) {
        updateW(notif: notif, signal: -0.3, delay: 0)
    }

    func recordIgnored(for notif: NotchNotification) {
        updateW(notif: notif, signal: -0.5, delay: 0)
    }

    private func updateW(notif: NotchNotification, signal: Double, delay: Double) {
        var profile = SemanticProfile.shared.current ?? SemanticProfileData()

        let key = notif.type.rawValue
        var w = profile.wValues[key] ?? 0.60

        // Response delay modifier
        let delayMod: Double
        switch delay {
        case ..<2:   delayMod = 1.0
        case 2..<8:  delayMod = 0.9
        default:     delayMod = 0.7
        }

        let adjustedSignal = signal * delayMod
        w = w * λ + adjustedSignal * (1 - λ)
        w = max(0.0, min(1.0, w))

        profile.wValues[key] = w
        SemanticProfile.shared.update(profile)

        // Update contextual bandit Q-value too
        ContextualBandit.shared.update(notif: notif, reward: signal > 0 ? signal : signal)
    }

    // W threshold → show frequency
    // ≥0.60: every occurrence
    // 0.30–0.59: every other
    // 0.10–0.29: suppress
    // <0.10: dead (manual re-enable)
    func shouldShow(notif: NotchNotification, urgency: Double) -> Bool {
        if urgency > 8.0 { return true }   // always show

        let w = SemanticProfile.shared.current?.wValues[notif.type.rawValue] ?? 0.60
        if w >= 0.60 { return true }
        if w >= 0.30 { return Bool.random() }  // every other = ~50%
        return false
    }
}
