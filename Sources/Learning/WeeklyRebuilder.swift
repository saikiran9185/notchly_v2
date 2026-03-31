import Foundation

// WEEKLY REBUILD — every Sunday 23:00
// NSBackgroundActivityScheduler fires weekly, reads episodic.jsonl,
// computes all learning metrics, writes semantic_profile.json atomically.
class WeeklyRebuilder {
    static let shared = WeeklyRebuilder()
    private init() {}

    private var scheduler: NSBackgroundActivityScheduler?

    func start() {
        scheduler = NSBackgroundActivityScheduler(identifier: "com.notchly.weekly")
        scheduler?.interval    = 7 * 24 * 3600
        scheduler?.repeats     = true
        scheduler?.tolerance   = 3600
        scheduler?.schedule { [weak self] completion in
            self?.rebuild()
            completion(.finished)   // NSBackgroundActivityScheduler.Result.finished
        }
    }

    func rebuild() {
        guard let lines = readEpisodicLines() else { return }

        var energyByHour: [String: [Double]] = [:]
        var wValues: [String: Double] = [:]
        var responseBuckets: [String: [String: Int]] = [:]
        var totalPoints = 0

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(EpisodicEntry.self, from: data)
            else { continue }

            totalPoints += 1

            // Accumulate energy by hour
            let h = String(entry.context.hour)
            var arr = energyByHour[h] ?? []
            arr.append(entry.context.energy)
            energyByHour[h] = arr

            // W values using exponential moving average
            let w = wValues[entry.notifType] ?? 0.60
            let signal: Double
            switch entry.action {
            case "done", "swipe_right": signal = 1.0
            case "postpone":            signal = 0.5
            case "skip", "swipe_left":  signal = -0.3
            case "ignored":             signal = -0.5
            default:                    signal = 0.0
            }
            wValues[entry.notifType] = w * 0.85 + signal * 0.15

            // Response buckets for ProActor timing
            let bucket = String(entry.context.hour / 2 * 2)
            if ["done", "swipe_right"].contains(entry.action) {
                var b = responseBuckets[entry.notifType] ?? [:]
                b[bucket] = (b[bucket] ?? 0) + 1
                responseBuckets[entry.notifType] = b
            }
        }

        // Average energy per hour slot
        var avgEnergyByHour: [String: Double] = [:]
        for (h, values) in energyByHour {
            avgEnergyByHour[h] = values.reduce(0, +) / Double(values.count)
        }

        // Build updated profile
        var profile = SemanticProfile.shared.current ?? SemanticProfileData()
        profile.energyByHour    = avgEnergyByHour
        profile.wValues         = wValues
        profile.responseBuckets = responseBuckets
        profile.totalDataPoints = totalPoints
        profile.lastRebuilt     = ISO8601DateFormatter().string(from: Date())
        profile.capBeta         = 0.2 + 0.8 * (1.0 - exp(-Double(totalPoints) / 100.0))

        SemanticProfile.shared.update(profile)
    }

    private func readEpisodicLines() -> [String]? {
        guard let content = try? String(contentsOf: DirectorySetup.episodicLog, encoding: .utf8)
        else { return nil }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
