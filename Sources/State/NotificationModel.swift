import Foundation
import SwiftUI

struct NotchNotification: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String = ""
    var type: NotifType
    var task: NotchTask?
    var timestamp: Date = Date()
    var wWeight: Double = 0.60       // confidence weight W
    var evrAtFire: Double = 0.0
    var context: NotifContext = NotifContext()

    // Button labels (default week 1; ButtonPlacementEngine overrides week 2+)
    var leftAction: String  = "Skip"
    var centerAction: String = "Later"
    var rightAction: String  = "Done"

    var dotHex: String {
        switch type {
        case .meal:      return "#BA7517"
        case .task:      return "#1D9E75"
        case .class_:    return "#4A90E2"
        case .exercise:  return "#1D9E75"
        case .deadline:  return "#E24B4A"
        case .lazy:      return "#D85A30"
        case .break_:    return "#7F77DD"
        default:         return "#5F5E5A"
        }
    }
}

struct NotifContext: Codable, Equatable {
    var hour: Int = Calendar.current.component(.hour, from: Date())
    var dayOfWeek: Int = Calendar.current.component(.weekday, from: Date())
    var hasClass: Bool = false
    var deadlineToday: Bool = false
    var energy: Double = 5.0
    var frontmost: String = ""
}

enum NotifType: String, Codable, Equatable {
    case task, meal, class_, exercise, deadline, lazy, break_, other

    var defaultButtons: (left: String, center: String, right: String) {
        switch self {
        case .task:      return ("Not yet", "Later", "Done ✓")
        case .meal:      return ("Skip", "Done", "Going now")
        case .class_:    return ("Skip", "Later", "On my way")
        case .exercise:  return ("Skip today", "Later", "Starting now")
        case .deadline:  return ("Move 8pm", "+30m", "Start now")
        case .lazy:      return ("10 more m", "Dismiss", "Get back to it")
        case .break_:    return ("5 more m", "Tomorrow", "Back now")
        default:         return ("Skip", "Later", "Done ✓")
        }
    }
}
