import SwiftUI

struct Stage2AView: View {
    @EnvironmentObject var state: NotchState

    var body: some View {
        // Background drawn by NotchRootView
        VStack(spacing: 8) {
            // ROW 1 — Header
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let task = state.currentTask {
                        Text(task.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NT.textPrimary)
                            .lineLimit(1)
                        Text(subtitleText)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(NT.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Queue clear")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NT.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(timeRemainingText)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(NT.textSecondary)

                    if let hint = state.context.suggestedApp {
                        AppLaunchButton(hint: hint)
                    }
                }
            }

            // ROW 2 — Progress bar
            if let task = state.currentTask {
                ProgressBar(progress: task.progressPercent)
            }

            // ROW 3 — Next up (skip current task to show real next)
            if let next = nextTask {
                HStack {
                    Text("next: \(next.title)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(NT.textTertiary)
                        .lineLimit(1)
                }
            }

            // ROW 4 — Action buttons
            buttonRow
        }
        .padding(.horizontal, 14)
        .padding(.top, NotchDimensions.shared.notchH - 4)
        .padding(.bottom, 12)
        // Collapse handled by HoverZoneMonitor — no onHover here (causes spurious collapses)
    }

    private var buttonRow: some View {
        let buttons = buttonSet
        return HStack(spacing: 5) {
            ActionButton(label: buttons.left, style: .secondary) { performLeft() }
            ActionButton(label: buttons.center, style: .muted) { performCenter() }
            ActionButton(label: buttons.right, style: isEscalated ? .danger : .primary) { performRight() }
        }
        .frame(height: 26)
    }

    private var buttonSet: (left: String, center: String, right: String) {
        if let notif = state.currentNotification { return notif.type.defaultButtons }
        if state.activeTimerTask != nil { return ("Not yet", "Take break", "Done ✓") }
        return ("Skip", "Later", "Done ✓")
    }

    private var isEscalated: Bool { state.currentTask?.isEscalated ?? false }

    private var subtitleText: String {
        guard let task = state.currentTask else { return "" }
        if let d = task.deadline {
            let h = Int(d.timeIntervalSinceNow / 3600)
            return h < 0 ? "overdue" : "due in \(h)h"
        }
        return task.category.rawValue
    }

    private var timeRemainingText: String {
        guard let task = state.currentTask else { return "" }
        return "\(task.estimatedMinutes)m est."
    }

    private func performRight() {
        if let notif = state.currentNotification {
            EpisodicLog.shared.append(action: "done", notification: notif, context: state.context)
            EVRUpdater.shared.recordPrimary(for: notif)
        }
        let next = nextLabel()
        let msg = next.isEmpty ? "\(state.currentTask?.title ?? "") done" : "\(state.currentTask?.title ?? "") done · \(next) up next"
        state.showContinuity(msg)
        state.collapse()
    }

    private func performLeft() {
        if let notif = state.currentNotification {
            EpisodicLog.shared.append(action: "skip", notification: notif, context: state.context)
            EVRUpdater.shared.recordDismissed(for: notif)
        }
        let next = nextLabel()
        state.showContinuity(next.isEmpty ? "Skipped" : "Skipped · \(next) up next")
        state.dismissCurrentNotification()
    }

    private func performCenter() {
        if let notif = state.currentNotification {
            EpisodicLog.shared.append(action: "postpone", notification: notif, context: state.context)
            EVRUpdater.shared.recordSecondary(for: notif)
        }
        if var task = state.currentTask {
            task.postponeCount += 1
            if task.postponeCount >= 3 {
                state.taskQueue.removeAll { $0.id == task.id }
                state.currentTask = state.taskQueue.first(where: { !$0.isCompleted })
                let nextTitle = state.currentTask?.title ?? "queue"
                state.showContinuity("Moved \(task.title) to tomorrow — \(nextTitle) up next")
            } else {
                if let idx = state.taskQueue.firstIndex(where: { $0.id == task.id }) {
                    state.taskQueue[idx] = task
                }
                let next = nextLabel()
                state.showContinuity(next.isEmpty ? "Moved later" : "Moved later · \(next) up next")
            }
        }
        state.collapse()
    }

    // Returns the next non-completed task that isn't the current one
    private var nextTask: NotchTask? {
        let currentId = state.currentTask?.id
        return state.taskQueue.first(where: { !$0.isCompleted && $0.id != currentId })
    }

    private func nextLabel() -> String { nextTask?.title ?? "" }
}
