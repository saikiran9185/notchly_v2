import Foundation

// MARK: - BDI types

struct Belief {
    let key: String
    var value: Bool
    var confidence: Double   // 0.0–1.0
}

struct Desire {
    let name: String
    var utility: Double
}

struct Intention {
    let name: String
    var expectedUtility: Double
    var costEstimate: Double

    var netValue: Double { expectedUtility - costEstimate }
}

// MARK: - BDIAgent

final class BDIAgent {
    static let shared = BDIAgent()

    private(set) var beliefs: [String: Belief] = [:]
    private(set) var desires: [Desire] = []
    private(set) var intentions: [Intention] = []

    private init() {}

    func initialize() {
        seedBeliefs()
        buildIntentions()
    }

    private func seedBeliefs() {
        beliefs["user.is_in_class"]    = Belief(key: "user.is_in_class",    value: false, confidence: 1.0)
        beliefs["user.is_deep_work"]   = Belief(key: "user.is_deep_work",   value: false, confidence: 1.0)
        beliefs["user.is_idle"]        = Belief(key: "user.is_idle",        value: false, confidence: 1.0)
        beliefs["task.deadline_today"] = Belief(key: "task.deadline_today", value: false, confidence: 1.0)
        beliefs["app.relevant"]        = Belief(key: "app.relevant",        value: false, confidence: 0.5)
    }

    func updateBelief(key: String, value: Bool, confidence: Double = 1.0) {
        beliefs[key] = Belief(key: key, value: value, confidence: confidence)
        buildIntentions()
    }

    private func buildIntentions() {
        var result: [Intention] = []

        if beliefs["user.is_in_class"]?.value == true {
            result.append(Intention(name: "enterClassMode", expectedUtility: 9, costEstimate: 0))
        }
        if beliefs["app.relevant"]?.value == true {
            result.append(Intention(name: "showAppButton", expectedUtility: 6, costEstimate: 1))
        }
        if beliefs["task.deadline_today"]?.value == true {
            result.append(Intention(name: "escalateDeadline", expectedUtility: 10, costEstimate: 2))
        }

        intentions = result.sorted { $0.netValue > $1.netValue }
    }

    func hasIntention(_ name: String) -> Bool {
        intentions.contains { $0.name == name }
    }
}
