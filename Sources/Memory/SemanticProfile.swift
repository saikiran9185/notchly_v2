import Foundation

// Semantic profile — rebuilt weekly. Single source of truth for all learned values.
class SemanticProfile {
    static let shared = SemanticProfile()
    private init() { load() }

    private(set) var current: SemanticProfileData?
    private let url = DirectorySetup.semanticProfile
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() {
        guard let data = try? Data(contentsOf: url),
              let profile = try? decoder.decode(SemanticProfileData.self, from: data)
        else {
            current = SemanticProfileData()
            return
        }
        current = profile
    }

    func update(_ profile: SemanticProfileData) {
        current = profile
        if let data = try? encoder.encode(profile) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// The actual data stored in semantic_profile.json
struct SemanticProfileData: Codable {
    var energyByHour: [String: Double] = [:]
    var avgDurationByCat: [String: Int] = [:]
    var wValues: [String: Double] = [:]     // W per notification type
    var optimalFireTimes: [String: String] = [:]
    var buttonPlacement: [String: [String: Int]] = [:]   // [contextKey: [action: count]]
    var banditQ: [String: [String: Double]] = [:]
    var responseBuckets: [String: [String: Int]] = [:]
    var capBeta: Double = 0.20
    var totalDataPoints: Int = 0
    var lastRebuilt: String = ""

    enum CodingKeys: String, CodingKey {
        case energyByHour       = "energy_by_hour"
        case avgDurationByCat   = "avg_duration_by_cat"
        case wValues            = "W_values"
        case optimalFireTimes   = "optimal_fire_times"
        case buttonPlacement    = "button_placement"
        case banditQ            = "bandit_Q"
        case responseBuckets    = "response_buckets"
        case capBeta            = "cap_beta"
        case totalDataPoints    = "total_data_points"
        case lastRebuilt        = "last_rebuilt"
    }
}
