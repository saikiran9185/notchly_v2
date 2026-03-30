import Foundation

struct NotchAlert: Identifiable, Codable {
    let id: UUID
    var type: NotifType
    var title: String
    var subtitle: String
    var leftAction: String
    var rightAction: String
    var centerAction: String?
    var wWeight: Double            // EVR W confidence
    var context: AlertContext
    var firedAt: Date
    var isEscalated: Bool

    init(id: UUID = UUID(), type: NotifType, title: String, subtitle: String,
         leftAction: String, rightAction: String, centerAction: String? = nil,
         wWeight: Double = 0.6) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.leftAction = leftAction
        self.rightAction = rightAction
        self.centerAction = centerAction
        self.wWeight = wWeight
        self.context = AlertContext()
        self.firedAt = Date()
        self.isEscalated = false
    }
}

struct AlertContext: Codable {
    var hour: Int
    var dayOfWeek: Int
    var hasClass: Bool
    var deadlineToday: Bool
    var energyLevel: Double
    var frontmostApp: String

    init() {
        let now = Date()
        let cal = Calendar.current
        self.hour = cal.component(.hour, from: now)
        self.dayOfWeek = cal.component(.weekday, from: now)
        self.hasClass = false
        self.deadlineToday = false
        self.energyLevel = 5.0
        self.frontmostApp = ""
    }
}

struct MissedAlert: Identifiable {
    let id: UUID
    let alert: NotchAlert
    let missedAt: Date
    var isExpanded: Bool = false

    var timeAgoString: String {
        let mins = Int(Date().timeIntervalSince(missedAt) / 60)
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }
}
