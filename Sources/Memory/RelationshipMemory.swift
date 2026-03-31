import Foundation

// Relationship memory — updated from Notion + Calendar.
// Stores projects, clients, deadlines, recurring events, class schedule.
class RelationshipMemory {
    static let shared = RelationshipMemory()
    private init() { load() }

    private(set) var data: RelationshipData = RelationshipData()
    private let url = DirectorySetup.relationships
    private let decoder = JSONDecoder()

    func load() {
        guard let raw = try? Data(contentsOf: url),
              let d = try? decoder.decode(RelationshipData.self, from: raw)
        else { return }
        data = d
    }

    func reload() { load() }
}

struct RelationshipData: Codable {
    var projects:        [ProjectInfo]   = []
    var clients:         [ClientInfo]    = []
    var deadlines:       [DeadlineInfo]  = []
    var recurringEvents: [RecurringInfo] = []
    var classSchedule:   [ClassInfo]     = []
}

struct ProjectInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var notionID: String?
    var deadline: Date?
}

struct ClientInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
}

struct DeadlineInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var taskTitle: String
    var dueDate: Date
    var priority: String
}

struct RecurringInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var dayOfWeek: Int
    var hour: Int
}

struct ClassInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var subject: String
    var dayOfWeek: Int
    var startHour: Int
    var durationMinutes: Int
    var location: String
}
