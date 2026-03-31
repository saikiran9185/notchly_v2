import Foundation

// Default energy curve (replaced by personal after 2 weeks of data)
// Energy 0.0–10.0 by hour of day
class EnergyModel {
    static let shared = EnergyModel()
    private init() {}

    // Default hourly energy values (from manifesto)
    private let defaultCurve: [Int: Double] = [
        0: 2.0, 1: 2.0, 2: 2.0, 3: 2.0, 4: 2.0,
        5: 4.0, 6: 5.0, 7: 5.0,
        8: 9.0, 9: 9.0, 10: 9.0, 11: 9.0,
        12: 6.0, 13: 5.0,
        14: 8.0, 15: 8.0, 16: 8.0,
        17: 6.0, 18: 6.0,
        19: 5.0, 20: 5.0,
        21: 4.0, 22: 4.0,
        23: 3.0
    ]

    // Current energy level — uses personal profile if available, else default
    func currentEnergy(at hour: Int, profile: SemanticProfileData? = nil) -> Double {
        if let profile = profile,
           let personal = profile.energyByHour[String(hour)] {
            return personal
        }
        return defaultCurve[hour] ?? 5.0
    }

    // Is this an energy peak slot? (E ≥ 8)
    func isPeakSlot(at hour: Int, profile: SemanticProfileData? = nil) -> Bool {
        currentEnergy(at: hour, profile: profile) >= 8.0
    }

    // Is this an energy dip? (E ≤ 5)
    func isDipSlot(at hour: Int, profile: SemanticProfileData? = nil) -> Bool {
        currentEnergy(at: hour, profile: profile) <= 5.0
    }

    // Energy label for UI display
    func label(for level: Double) -> String {
        switch level {
        case 8...:  return "peak"
        case 6..<8: return "high"
        case 4..<6: return "normal"
        case 2..<4: return "low"
        default:    return "very low"
        }
    }
}
