import Foundation
import EventKit

struct ContextSnapshot {
    var hour: Int
    var energyLevel: Double
    var activeEvent: EKEvent?
    var eventType: EventType
    var frontmostApp: String
    var runningApps: Set<String>
    var idleMinutes: Int
    var isDeepWork: Bool
    var isInClass: Bool
    var missedCount: Int
    var dayProgress: Double
    var maxDeadlinePressure: Double
    var suggestedApp: AppLaunchHint?

    init() {
        let cal = Calendar.current
        let now = Date()
        self.hour = cal.component(.hour, from: now)
        self.energyLevel = 5.0
        self.activeEvent = nil
        self.eventType = .free
        self.frontmostApp = ""
        self.runningApps = []
        self.idleMinutes = 0
        self.isDeepWork = false
        self.isInClass = false
        self.missedCount = 0
        self.dayProgress = 0.0
        self.maxDeadlinePressure = 0.0
        self.suggestedApp = nil
    }
}

enum EventType {
    case `class`, work, meal, personal, free
}

struct AppLaunchHint {
    var appName: String
    var bundleID: String
    var isRunning: Bool
    var isFrontmost: Bool
}
