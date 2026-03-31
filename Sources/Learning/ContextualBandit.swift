import Foundation

// LAYER 2 — Contextual Bandit: per-context Q-values
// context vector x = [hour_bucket(2h), day_of_week, has_class_2h,
//                     deadline_today, energy_bucket(2), frontmost_cat]
// Q(x, action) updated after each response (α=0.15)
class ContextualBandit {
    static let shared = ContextualBandit()
    private init() {}

    private let α = 0.15   // learning rate

    // Q-values: [contextKey: [action: qValue]]
    private var qTable: [String: [String: Double]] = [:]

    func update(notif: NotchNotification, reward: Double) {
        let key  = contextKey(notif.context)
        let act  = notif.type.rawValue

        var table = qTable[key] ?? [:]
        let oldQ  = table[act] ?? 0.0
        table[act] = oldQ + α * (reward - oldQ)
        qTable[key] = table

        // Persist to semantic profile
        var profile = SemanticProfile.shared.current ?? SemanticProfileData()
        profile.banditQ = qTable
        SemanticProfile.shared.update(profile)
    }

    // Best action for given context
    func bestAction(for context: NotifContext) -> String? {
        let key = contextKey(context)
        return qTable[key]?.max(by: { $0.value < $1.value })?.key
    }

    // Context vector → string key
    private func contextKey(_ ctx: NotifContext) -> String {
        let hourBucket = (ctx.hour / 2) * 2   // bucket to 2h
        let energyBucket = ctx.energy >= 6 ? "high" : "low"
        return "\(hourBucket)_\(ctx.dayOfWeek)_\(ctx.hasClass)_\(ctx.deadlineToday)_\(energyBucket)"
    }

    private func contextKey(_ ctx: ContextSnapshot) -> String {
        let hourBucket = (ctx.hour / 2) * 2
        let energyBucket = ctx.energyLevel >= 6 ? "high" : "low"
        let day = Calendar.current.component(.weekday, from: Date())
        return "\(hourBucket)_\(day)_\(ctx.isInClass)_\(ctx.maxDeadlinePressure > 5)_\(energyBucket)"
    }
}
