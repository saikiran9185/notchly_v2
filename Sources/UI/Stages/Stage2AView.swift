import SwiftUI

// Stage 2A — NowCard (interactive, 3 action buttons)
// Trigger: click s1 bar OR scroll δy 50–120pt
struct Stage2AView: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let pillW: CGFloat = 380

    var body: some View {
        ZStack(alignment: .top) {
            AsymmetricRoundedRect(topRadius: StageRadii.s2.top,
                                  bottomRadius: StageRadii.s2.bottom)
                .fill(NT.surface)
                .overlay(
                    AsymmetricRoundedRect(topRadius: StageRadii.s2.top,
                                         bottomRadius: StageRadii.s2.bottom)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

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

                // ROW 3 — Next up
                if let next = state.taskQueue.first {
                    HStack {
                        Text("next: \(next.title) · P=\(String(format: "%.1f", next.pFinal))")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(NT.textTertiary)
                            .lineLimit(1)
                    }
                }

                // ROW 4 — Action buttons
                buttonRow
            }
            .padding(.horizontal, 14)
            .padding(.top, notchH - 4)
            .padding(.bottom, 12)
        }
        .frame(width: pillW, height: notchH + 88)
        .onHover { hovered in
            if !hovered { state.collapse() }
        }
    }

    // MARK: - Button row (3 buttons per notification type)
    private var buttonRow: some View {
        let buttons = buttonSet
        return HStack(spacing: 5) {
            ActionButton(label: buttons.left, style: .secondary) { performLeft() }
            ActionButton(label: buttons.center, style: .muted) { performCenter() }
            ActionButton(label: buttons.right,
                         style: isEscalated ? .danger : .primary) { performRight() }
        }
        .frame(height: 26)
    }

    private var buttonSet: (left: String, center: String, right: String) {
        if let notif = state.currentNotification {
            return notif.type.defaultButtons
        }
        if state.activeTimerTask != nil {
            return ("Not yet", "Take break", "Done ✓")
        }
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
        state.showContinuity("\(state.currentTask?.title ?? "") done · \(nextLabel()) loading")
        state.collapse()
    }

    private func performLeft() {
        if let notif = state.currentNotification {
            EpisodicLog.shared.append(action: "skip", notification: notif, context: state.context)
            EVRUpdater.shared.recordDismissed(for: notif)
        }
        state.showContinuity("Skipped · \(nextLabel()) loading")
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
                state.showContinuity("Moved to tomorrow — postponed 3×")
            } else {
                state.showContinuity("Moved later · \(nextLabel()) loading")
            }
        }
        state.collapse()
    }

    private func nextLabel() -> String { state.taskQueue.first?.title ?? "next task" }
}
