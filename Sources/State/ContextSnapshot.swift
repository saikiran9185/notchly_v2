import Foundation
import EventKit

struct ContextSnapshot {
    var hour: Int = Calendar.current.component(.hour, from: Date())
    var energyLevel: Double = 5.0
    var activeEvent: EKEvent?
    var eventType: EventType = .free
    var frontmostApp: String = ""           // bundle ID
    var runningApps: Set<String> = []
    var idleMinutes: Int = 0
    var isDeepWork: Bool = false            // same app >20min + no switches
    var isInClass: Bool = false
    var missedCount: Int = 0
    var dayProgress: Double = 0.0           // 0.0–1.0
    var maxDeadlinePressure: Double = 0.0   // highest U across all tasks
    var suggestedApp: AppLaunchHint?
}

enum EventType {
    case `class`, work, meal, personal, free
}

struct AppLaunchHint {
    var bundleID: String
    var displayName: String
    var isRunning: Bool
    var isFrontmost: Bool
}
