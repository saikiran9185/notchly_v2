import Foundation

// LAYER 4 — ProActor Timing: shift fire time toward response time
// Track: response_bucket[type][hourBucket(0.5h)]++
// After 14+ days: optimal_hour = argmax(response_bucket[type])
// new_fire_time = scheduled × 0.70 + optimal × 0.30
class ProActorTimer {
    static let shared = ProActorTimer()
    private init() {}

    // Record that a notification of type was responded to at this hour
    func recordResponse(type: NotifType, hour: Double) {
        var profile = SemanticProfile.shared.current ?? SemanticProfileData()
        let typeKey  = type.rawValue
        let bucket   = String(Int(hour * 2) / 2)  // 0.5h buckets → Int bucket

        var buckets = profile.responseBuckets[typeKey] ?? [:]
        buckets[bucket] = (buckets[bucket] ?? 0) + 1
        profile.responseBuckets[typeKey] = buckets
        SemanticProfile.shared.update(profile)
    }

    // Optimal fire hour for notification type (nil = not enough data)
    func optimalHour(for type: NotifType) -> Double? {
        guard let profile = SemanticProfile.shared.current,
              let buckets = profile.responseBuckets[type.rawValue],
              profile.totalDataPoints >= 14 * 3  // roughly 14 days of data
        else { return nil }

        guard let best = buckets.max(by: { $0.value < $1.value }) else { return nil }
        return Double(best.key) ?? nil
    }

    // Adjusted fire time
    func adjustedFireTime(scheduled: Date, type: NotifType) -> Date {
        guard let optHour = optimalHour(for: type) else { return scheduled }
        let scheduledHour = Calendar.current.component(.hour, from: scheduled)
        let blended = Double(scheduledHour) * 0.70 + optHour * 0.30
        var comps = Calendar.current.dateComponents(
            [.year, .month, .day], from: scheduled)
        comps.hour   = Int(blended)
        comps.minute = Int((blended - Double(Int(blended))) * 60)
        return Calendar.current.date(from: comps) ?? scheduled
    }
}
