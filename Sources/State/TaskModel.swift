import Foundation

struct NotchTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var category: TaskCategory
    var deadline: Date?
    var durationMinutes: Int
    var progressPct: Double        // 0.0–1.0
    var priority: TaskPriority
    var postponeCount: Int
    var skipCount: Int
    var rejectionCount: Int
    var isEscalated: Bool
    var relatedApp: String?        // bundle ID

    // Scoring fields (computed by PriorityScorer)
    var pScore: Double
    var urgencyScore: Double
    var importanceScore: Double
    var energyMatchScore: Double
    var contextFitScore: Double
    var deadlineMomentumScore: Double

    init(id: UUID = UUID(), title: String, subtitle: String = "",
         category: TaskCategory = .other, deadline: Date? = nil,
         durationMinutes: Int = 30, progressPct: Double = 0,
         priority: TaskPriority = .medium) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.deadline = deadline
        self.durationMinutes = durationMinutes
        self.progressPct = progressPct
        self.priority = priority
        self.postponeCount = 0
        self.skipCount = 0
        self.rejectionCount = 0
        self.isEscalated = false
        self.relatedApp = nil
        self.pScore = 0
        self.urgencyScore = 0
        self.importanceScore = 0
        self.energyMatchScore = 0
        self.contextFitScore = 0
        self.deadlineMomentumScore = 0
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case deepWork, creative, study, admin, review, meeting
    case meal, exercise, `class`, `break`, other

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

    var sfSymbol: String {
        switch self {
        case .deepWork:  return "brain"
        case .creative:  return "pencil.and.outline"
        case .study:     return "book"
        case .admin:     return "checklist"
        case .review:    return "eye"
        case .meeting:   return "person.2"
        case .meal:      return "fork.knife"
        case .exercise:  return "figure.run"
        case .class:     return "graduationcap"
        case .break:     return "cup.and.saucer"
        case .other:     return "circle"
        }
    }
}

enum TaskPriority: Int, Codable, CaseIterable {
    case urgent = 1, high = 2, medium = 3, low = 4

    var importanceScore: Double {
        switch self {
        case .urgent: return 10.0
        case .high:   return 7.0
        case .medium: return 4.0
        case .low:    return 1.0
        }
    }
}
