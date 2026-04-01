import SwiftUI

struct Stage15View: View {
    @EnvironmentObject var state: NotchState

    var body: some View {
        // Background drawn by NotchRootView — content only
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: task + time + progress %
            HStack(spacing: 8) {
                Circle()
                    .fill(taskColor)
                    .frame(width: 7, height: 7)
                Text(row1Text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NT.textPrimary)
                    .lineLimit(1)
            }

            // Row 2: next task + missed alert if any
            HStack(spacing: 6) {
                Text(row2Text)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(NT.textSecondary)
                    .lineLimit(1)

                if state.missedNotifications.isEmpty == false {
                    Text("MISSED · \(state.missedNotifications.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NT.red)
                        .tracking(0.06 * 10)
                }
            }

            // Row 3: scroll hint
            Text("scroll ↓ to act")
                .font(.system(size: 9.5, weight: .regular))
                .foregroundColor(NT.textTertiary)
                .opacity(0.6)
        }
    }

    private var taskColor: Color {
        if let task = state.currentTask {
            switch task.category {
            case .meal:     return NT.amber
            case .class:    return NT.blue
            case .exercise: return NT.green
            case .deepWork: return NT.purple
            default:        return NT.green
            }
        }
        return NT.gray
    }

    private var row1Text: String {
        guard let task = state.currentTask else { return "No active task" }
        let pct = Int(task.progressPercent * 100)
        if let deadline = task.deadline {
            let mins = Int(deadline.timeIntervalSinceNow / 60)
            if mins < 60 { return "\(task.title) · \(mins)m left · \(pct)% done" }
            let hrs = mins / 60
            return "\(task.title) · \(hrs)h left · \(pct)% done"
        }
        return "\(task.title) · \(pct)% done"
    }

    private var row2Text: String {
        guard let next = state.taskQueue.first else { return "Queue clear" }
        if let start = next.scheduledStart {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "next: \(next.title) · \(fmt.string(from: start))"
        }
        return "next: \(next.title)"
    }
}
