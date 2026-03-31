import Foundation

// P = (U×0.35) + (I×0.25) + (E×0.20) + (C×0.15) + (D×0.05)
// Weight validation: assert at startup
class PriorityScorer {
    static let shared = PriorityScorer()
    private init() {
        let weights = [0.35, 0.25, 0.20, 0.15, 0.05]
        assert(abs(weights.reduce(0, +) - 1.0) < 0.0001,
               "FATAL: P score weights must sum to 1.0")
    }

    func score(_ task: NotchTask, context: ContextSnapshot) -> NotchTask {
        var t = task
        t.urgency        = computeU(task)
        t.importance     = computeI(task)
        t.energyMatch    = computeE(task, energy: context.energyLevel)
        t.contextFit     = computeC(task, context: context)
        t.deadlineMomentum = computeD(task)

        var raw = (t.urgency * 0.35)
                + (t.importance * 0.25)
                + (t.energyMatch * 0.20)
                + (t.contextFit * 0.15)
                + (t.deadlineMomentum * 0.05)

        // Skip penalty: P_final = P_raw × pow(0.8, skipCount)
        raw *= pow(0.8, Double(t.skipCount))
        t.pFinal = max(0, min(10, raw))
        return t
    }

    // U — Urgency (0.0–10.0)
    // k = 0.15, h = hoursUntilDeadline
    // overdue (h<0): U=10  no deadline: U=2  else: U=10×exp(-0.15×h)
    private func computeU(_ task: NotchTask) -> Double {
        guard let h = task.hoursUntilDeadline else { return 2.0 }
        if h < 0 { return 10.0 }
        return 10.0 * exp(-0.15 * h)
    }

    // I — Importance (0.0–10.0)
    // Postpone penalty: I = max(0, I − 0.5 × postponeCount)
    private func computeI(_ task: NotchTask) -> Double {
        let base = task.priority.importanceScore
        let penalized = base - 0.5 * Double(task.postponeCount)
        return max(0, penalized)
    }

    // E — Energy Match (0.0–10.0)
    // E = 10.0 × min(1.0, currentEnergy / taskRequirement)
    private func computeE(_ task: NotchTask, energy: Double) -> Double {
        let req = task.category.energyRequirement
        guard req > 0 else { return 10.0 }
        return 10.0 * min(1.0, energy / req)
    }

    // C — Context Fit (0.0–10.0)
    private func computeC(_ task: NotchTask, context: ContextSnapshot) -> Double {
        // In class + non-class task = 0
        if context.isInClass && task.category != .class { return 0.0 }
        // Meal time + meal task = 10
        if task.category == .meal {
            // Simplified: meal tasks score 10 at breakfast/lunch/dinner hours
            let h = context.hour
            if (h >= 7 && h <= 9) || (h >= 12 && h <= 14) || (h >= 19 && h <= 21) {
                return 10.0
            }
        }
        // App relevance
        if let bundleID = task.relatedAppBundleID {
            if context.frontmostApp == bundleID { return 10.0 }
            if context.runningApps.contains(bundleID) { return 9.0 }
            return 7.0
        }
        return 5.0  // neutral
    }

    // D — Deadline Momentum (0.0–10.0)
    // h<6 OR h>72: D=0  |  6≤h≤72: D=10×(1−h/72)
    private func computeD(_ task: NotchTask) -> Double {
        guard let h = task.hoursUntilDeadline else { return 0.0 }
        if h < 6 || h > 72 { return 0.0 }
        return 10.0 * (1.0 - h / 72.0)
    }

    func scoreAll(_ tasks: [NotchTask], context: ContextSnapshot) -> [NotchTask] {
        tasks.map { score($0, context: context) }
             .sorted { $0.pFinal > $1.pFinal }
    }
}
