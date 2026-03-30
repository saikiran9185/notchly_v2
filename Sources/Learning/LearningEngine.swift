import Foundation

/// Implements the EVR (Expected Value with Regret) online learning loop.
/// After N=7 samples the model switches from default priors to learned weights.
final class LearningEngine {

    static let shared = LearningEngine()

    private let minSamplesForPersonal = 7
    private let persistURL = DirectorySetup.semanticProfile
    private var model = EVRModel()

    private init() {
        loadModel()
    }

    // MARK: - Record events

    func recordAccept(alert: NotchAlert) {
        model.record(context: alert.context, outcome: 1.0, type: alert.type)
        persist()
    }

    func recordDismiss(alert: NotchAlert) {
        model.record(context: alert.context, outcome: 0.0, type: alert.type)
        persist()
    }

    func recordTaskDone(task: NotchTask) {
        model.taskSamples += 1
        persist()
    }

    func recordPostpone(task: NotchTask) {
        model.postponeSamples += 1
        persist()
    }

    // MARK: - Query

    /// Returns predicted accept probability (W) for a given context and alert type.
    func predictW(context: AlertContext, type: NotifType) -> Double {
        guard model.totalSamples >= minSamplesForPersonal else { return 0.6 }
        return model.predict(context: context, type: type)
    }

    // MARK: - Persist

    private func persist() {
        guard let data = try? JSONEncoder().encode(model) else { return }
        try? data.writeAtomically(to: persistURL)
    }

    private func loadModel() {
        guard let data = try? Data(contentsOf: persistURL),
              let m = try? JSONDecoder().decode(EVRModel.self, from: data) else { return }
        model = m
    }
}

// MARK: - EVRModel

struct EVRModel: Codable {

    var totalSamples: Int = 0
    var taskSamples: Int = 0
    var postponeSamples: Int = 0

    // Per-type accept rates
    var typeAcceptRates: [String: Double] = [:]
    var typeAcceptCounts: [String: Int] = [:]

    // Hour-of-day accept buckets (0–23)
    var hourBuckets: [Int: Double] = [:]
    var hourCounts: [Int: Int] = [:]

    mutating func record(context: AlertContext, outcome: Double, type: NotifType) {
        totalSamples += 1
        let key = type.rawValue
        let prev = typeAcceptRates[key] ?? 0.5
        let n    = Double((typeAcceptCounts[key] ?? 0) + 1)
        typeAcceptRates[key]  = prev + (outcome - prev) / n
        typeAcceptCounts[key] = Int(n)

        let h = context.hour
        let hPrev = hourBuckets[h] ?? 0.5
        let hN    = Double((hourCounts[h] ?? 0) + 1)
        hourBuckets[h] = hPrev + (outcome - hPrev) / hN
        hourCounts[h]  = Int(hN)
    }

    func predict(context: AlertContext, type: NotifType) -> Double {
        let typeRate = typeAcceptRates[type.rawValue] ?? 0.6
        let hourRate = hourBuckets[context.hour] ?? 0.6
        // Simple weighted blend
        return typeRate * 0.6 + hourRate * 0.4
    }
}
