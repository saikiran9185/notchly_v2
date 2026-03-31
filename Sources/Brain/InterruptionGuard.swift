import Foundation

// EVR = p_forgotten × p_action × (benefit − cost_missing) − COI
// Gate: EVR > 0 → fire. EVR ≤ 0 → retry in 5min (max 6 retries).
// urgency > 8 → ALWAYS fire (safety override).
class InterruptionGuard {
    static let shared = InterruptionGuard()
    private init() {}

    // Returns true if notification should fire now
    func shouldFire(_ notification: NotchNotification,
                    task: NotchTask,
                    context: ContextSnapshot,
                    profile: SemanticProfileData?) -> Bool {
        // Safety override: urgency > 8 always fires
        if task.urgency > 8.0 { return true }

        let evr = computeEVR(notification, task: task, context: context, profile: profile)
        return evr > 0
    }

    func computeEVR(_ notification: NotchNotification,
                    task: NotchTask,
                    context: ContextSnapshot,
                    profile: SemanticProfileData?) -> Double {
        let pForgotten = computePForgotten(notification, profile: profile)
        let pAction    = profile?.wValues[notification.type.rawValue] ?? 0.60
        let benefit    = task.pFinal
        let costMiss   = task.pFinal * 1.5
        let coi        = computeCOI(context: context)

        return pForgotten * pAction * (benefit - costMiss) - coi
    }

    // p_forgotten: probability user forgot about this alert type
    // minutesSinceLastSeen — lower minutes = more likely remembered
    private func computePForgotten(_ notification: NotchNotification,
                                   profile: SemanticProfileData?) -> Double {
        // Simplified: use notification age in minutes
        let minutes = -notification.timestamp.timeIntervalSinceNow / 60
        return 1.0 - 1.0 / (1.0 + exp(-0.1 * minutes))
    }

    // COI — Cost of Interruption
    // base=2.0, multiplied by attention and time factors
    private func computeCOI(context: ContextSnapshot) -> Double {
        let base = 2.0

        let attention: Double
        if context.isInClass       { attention = 4.0 }
        else if context.isDeepWork { attention = 2.5 }
        else if context.idleMinutes > 10 { attention = 0.5 }
        else                       { attention = 1.0 }

        // Simplified: time factor (no last interruption timestamp here)
        let timeFactor = 1.0

        return base * attention * timeFactor
    }
}

// Retry queue entry
struct RetryEntry {
    let notification: NotchNotification
    let task: NotchTask
    var retryCount: Int
    var nextRetry: Date
}
