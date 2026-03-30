import Foundation

/// Default energy curve (hours 0–24 → energy 0–10).
/// Replaced by personal model after 2 weeks of data.
final class EnergyModel {
    static let shared = EnergyModel()
    private init() {}

    private let defaultCurve: [ClosedRange<Int>: Double] = [
        0...4:  2.0,
        5...5:  4.0,
        6...7:  5.0,
        8...11: 9.0,
        12...12: 6.0,
        13...13: 5.0,
        14...16: 8.0,
        17...18: 6.0,
        19...20: 5.0,
        21...22: 4.0,
        23...23: 3.0
    ]

    func energyLevel(at hour: Int) -> Double {
        for (range, value) in defaultCurve {
            if range.contains(hour) { return value }
        }
        return 4.0
    }
}
