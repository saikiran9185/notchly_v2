import Foundation

struct NotchTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String = ""
    var category: TaskCategory = .other
    var priority: TaskPriority = .medium
    var deadline: Date?
    var scheduledStart: Date?
    var estimatedMinutes: Int = 30
    var progressPercent: Double = 0.0
    var isCompleted: Bool = false
    var skipCount: Int = 0
    var postponeCount: Int = 0
    var rejectionCount: Int = 0
    var isEscalated: Bool = false
    var relatedAppBundleID: String?
    var notionID: String?

    // P score components (computed by PriorityScorer, stored for display)
    var urgency: Double = 2.0
    var importance: Double = 5.0
    var energyMatch: Double = 5.0
    var contextFit: Double = 5.0
    var deadlineMomentum: Double = 0.0
    var pFinal: Double = 0.0

    // Hours until deadline (negative = overdue)
    var hoursUntilDeadline: Double? {
        guard let d = deadline else { return nil }
        return d.timeIntervalSinceNow / 3600.0
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case deepWork = "deep_work"
    case creative
    case study
    case admin
    case review
    case meeting
    case meal
    case exercise
    case `class`
    case `break`
    case other

    var energyRequirement: Double {
        switch self {
        case .deepWork:  return 6.5
        case .creative:  return 6.0
        case .study:     return 6.5
        case .admin:     return 3.0
        case .review:    return 4.0
        case .meeting:   return 5.0
        case .meal:      return 1.0
        case .exercise:  return 5.5
        case .class:     return 5.0
        case .break:     return 1.0
        case .other:     return 4.0
        }
    }
}

enum TaskPriority: String, Codable {
    case urgent = "P1"
    case high   = "P2"
    case medium = "P3"
    case low    = "P4"

    var importanceScore: Double {
        switch self {
        case .urgent: return 10.0
        case .high:   return 7.0
        case .medium: return 4.0
        case .low:    return 1.0
        }
    }
}
