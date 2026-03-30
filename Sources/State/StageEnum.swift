import Foundation

enum NotchStage: Equatable {
    case s0_idle
    case s1a_notification
    case s1b_timer
    case s1_5_hover
    case s2a_nowcard
    case s2b_missed
    case s3_dashboard
    case s4_chat
    case s1_5x_diagnosis

    // Priority: highest wins
    var priority: Int {
        switch self {
        case .s4_chat:          return 8
        case .s3_dashboard:     return 7
        case .s2a_nowcard:      return 6
        case .s2b_missed:       return 5
        case .s1a_notification: return 4
        case .s1b_timer:        return 3
        case .s1_5_hover:       return 2
        case .s1_5x_diagnosis:  return 2
        case .s0_idle:          return 0
        }
    }
}

enum NotifType: String, Codable {
    case task, meal, `class`, exercise, deadline, lazy, `break`, general
}

enum NotifColor {
    static func color(for type: NotifType) -> String {
        switch type {
        case .meal:     return "#BA7517"
        case .task:     return "#1D9E75"
        case .class:    return "#4A90E2"
        case .exercise: return "#1D9E75"
        case .deadline: return "#E24B4A"
        case .lazy:     return "#D85A30"
        case .break:    return "#7F77DD"
        case .general:  return "#5F5E5A"
        }
    }
}
