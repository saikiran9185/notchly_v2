import Foundation

/// Computes priority score P = U×0.35 + I×0.25 + E×0.20 + C×0.15 + D×0.05
/// Weight sum is validated at app startup.
final class PriorityScorer {

    static let shared = PriorityScorer()

    private let wU: Double = 0.35
    private let wI: Double = 0.25
    private let wE: Double = 0.20
    private let wC: Double = 0.15
    private let wD: Double = 0.05

    private init() {
        let sum = [wU, wI, wE, wC, wD].reduce(0, +)
        assert(abs(sum - 1.0) < 0.0001, "Priority weights must sum to 1.0, got \(sum)")
    }

    func score(_ task: inout NotchTask, context: ContextSnapshot) {
        let U = urgency(task: task)
        let I = importance(task: task)
        let E = energyMatch(task: task, context: context)
        let C = contextFit(task: task, context: context)
        let D = deadlineMomentum(task: task)

        task.urgencyScore         = U
        task.importanceScore      = I
        task.energyMatchScore     = E
        task.contextFitScore      = C
        task.deadlineMomentumScore = D

        var P = U * wU + I * wI + E * wE + C * wC + D * wD
        // Skip penalty
        P = P * pow(0.8, Double(task.skipCount))
        task.pScore = P
    }

    // MARK: - Component formulas

    private func urgency(task: NotchTask) -> Double {
        guard let deadline = task.deadline else { return 2.0 }
        let h = deadline.timeIntervalSinceNow / 3600
        if h < 0 { return 10.0 }
        return 10.0 * exp(-0.15 * h)
    }

    private func importance(task: NotchTask) -> Double {
        var I = task.priority.importanceScore
        I = max(0, I - 0.5 * Double(task.postponeCount))
        return I
    }

    private func energyMatch(task: NotchTask, context: ContextSnapshot) -> Double {
        let current = context.energyLevel
        let required = task.category.energyRequirement
        return 10.0 * min(1.0, current / required)
    }

    private func contextFit(task: NotchTask, context: ContextSnapshot) -> Double {
        if context.isInClass && task.category != .class { return 0.0 }
        if task.category == .meal { return 10.0 }
        if let app = task.relatedApp {
            if context.frontmostApp == app    { return 10.0 }
            if context.runningApps.contains(app) { return 9.0 }
            return 7.0
        }
        return 5.0
    }

    private func deadlineMomentum(task: NotchTask) -> Double {
        guard let deadline = task.deadline else { return 0.0 }
        let h = deadline.timeIntervalSinceNow / 3600
        guard h >= 6, h <= 72 else { return 0.0 }
        return 10.0 * (1.0 - h / 72.0)
    }
}
