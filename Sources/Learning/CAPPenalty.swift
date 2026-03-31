import Foundation

// LAYER 3 — CAP Penalty: β confidence scaling
// β = 0.2 + 0.8 × (1 − exp(−dataPoints / 100))
// 0 rows: β≈0.20   100 rows: β≈0.70   300 rows: β≈0.95
// penalty = β × COI × interruptionsToday
// adjusted_score = task.P_final − penalty
// urgency>8.0: bypass CAP always
class CAPPenalty {
    static let shared = CAPPenalty()
    private init() {}

    var beta: Double {
        let n = Double(EpisodicLog.shared.totalDataPoints())
        return 0.2 + 0.8 * (1.0 - exp(-n / 100.0))
    }

    func adjusted(score: Double, urgency: Double,
                  coi: Double, interruptionsToday: Int) -> Double {
        if urgency > 8.0 { return score }
        let penalty = beta * coi * Double(interruptionsToday)
        return max(0, score - penalty)
    }
}
