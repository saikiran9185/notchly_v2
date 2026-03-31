import SwiftUI

// Stage 3 — Full Dashboard
// Trigger: scroll δy > 120pt OR "see all" tap OR ⌘Space
struct Stage3View: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let pillW: CGFloat = 520

    @State private var completedIDs: Set<UUID> = []
    @State private var currentPulse: Bool = false

    private let sectionBg    = Color.white.opacity(0.025)
    private let sectionBorder = Color.white.opacity(0.04)

    var body: some View {
        ZStack(alignment: .top) {
            AsymmetricRoundedRect(topRadius: StageRadii.s3.top,
                                  bottomRadius: StageRadii.s3.bottom)
                .fill(Color(hex: "#0c0c0c"))
                .overlay(
                    AsymmetricRoundedRect(topRadius: StageRadii.s3.top,
                                         bottomRadius: StageRadii.s3.bottom)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )

            VStack(spacing: 8) {
                // Row 1: Timeline | Tasks Left
                HStack(spacing: 6) {
                    timelineCard
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: 0)

                    tasksCard
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: 0)
                }

                // Row 2: Now+Prep | Day Score
                HStack(spacing: 6) {
                    nowPrepCard
                    dayScoreCard
                }

                // Full-width chat hint
                chatHintBar
            }
            .padding(.horizontal, 12)
            .padding(.top, notchH + 12)
            .padding(.bottom, 14)
        }
        .frame(width: pillW)
        .frame(minHeight: 280, maxHeight: 400)
        .onHover { hovered in if !hovered { state.collapse() } }
        .gesture(TapGesture(count: 2).onEnded {
            state.transition(to: .s4_chat, spring: Springs.expand)
        })
    }

    // MARK: - Section card wrapper
    @ViewBuilder
    private func sectionCard<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.18))
                .tracking(0.08 * 9)

            content()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(sectionBg)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(sectionBorder, lineWidth: 0.5))
        )
    }

    // MARK: - Timeline card (Left Row 1)
    private var timelineCard: some View {
        sectionCard("TODAY") {
            // Placeholder items — populated by ContextEngine
            let items = todayTimelineItems
            VStack(spacing: 0) {
                ForEach(items.prefix(6), id: \.id) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(timelineItemColor(item))
                            .frame(width: 4, height: 4)
                            .overlay(
                                item.isCurrent ?
                                    Circle().fill(NT.green).frame(width: 4, height: 4)
                                        .opacity(currentPulse ? 0.6 : 1.0)
                                        .animation(.easeInOut(duration: 1.2).repeatForever(), value: currentPulse)
                                    : nil
                            )

                        Text(item.time)
                            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                            .foregroundColor(NT.textTertiary)
                            .frame(width: 38, alignment: .leading)

                        Text(item.label)
                            .font(.system(size: 10.5, weight: item.isCurrent ? .medium : .regular))
                            .foregroundColor(item.isDone ? .white.opacity(0.25)
                                             : item.isCurrent ? NT.textPrimary : NT.textSecondary)
                            .lineLimit(1)

                        if item.isCurrent {
                            Text("▶").font(.system(size: 8)).foregroundColor(NT.green)
                        }
                    }
                    .frame(height: 18)
                }
            }
            .onAppear { currentPulse = true }
        }
    }

    // MARK: - Tasks card (Right Row 1)
    private var tasksCard: some View {
        sectionCard("TASKS · tap ✓ to mark done") {
            VStack(spacing: 0) {
                ForEach(state.taskQueue.prefix(5)) { task in
                    HStack(spacing: 6) {
                        TaskTickButton(isDone: completedIDs.contains(task.id)) {
                            withAnimation(Springs.missedRemove) {
                                completedIDs.insert(task.id)
                            }
                            EpisodicLog.shared.append(action: "done", notification: nil,
                                                      context: state.context, task: task)
                            state.showContinuity("\(task.title) done")
                        }

                        Text(task.title)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(NT.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .strikethrough(completedIDs.contains(task.id), color: .white.opacity(0.25))

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("P=\(String(format: "%.1f", task.pFinal))")
                                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.18))
                            MiniProgressBar(progress: task.progressPercent)
                        }
                    }
                    .frame(height: 26)
                }
            }
        }
    }

    // MARK: - Now+Prep card (Left Row 2)
    private var nowPrepCard: some View {
        sectionCard("NOW · PREP") {
            if let task = state.currentTask {
                Text("\(task.title) · \(timerDisplay)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(NT.green)
                    .lineLimit(1)
            }
            if let next = state.taskQueue.first {
                Text("after: \(next.title)")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(NT.textSecondary)
                    .lineLimit(1)
            }
            if state.context.isInClass {
                Text("class mode active")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(NT.blue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Score card (Right Row 2)
    private var dayScoreCard: some View {
        sectionCard("DAY") {
            Text("\(state.doneToday) done · \(state.leftToday) left")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(NT.textPrimary)
            Text("energy: \(energyLabel)")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundColor(NT.textSecondary)
            if !state.missedNotifications.isEmpty {
                Text("missed · \(state.missedNotifications.count) need response")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(NT.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chat hint bar
    private var chatHintBar: some View {
        HStack {
            Circle().fill(NT.purple.opacity(0.35)).frame(width: 5, height: 5)
            Text("double-tap to chat · add task · ask anything")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(NT.purple.opacity(0.20), lineWidth: 0.5))
        )
    }

    // MARK: - Helpers
    private var timerDisplay: String {
        let s = state.timerSecondsLeft
        guard s > 0 else { return state.currentTask?.title ?? "" }
        if s > 3600 { return "\(s/3600)h \((s%3600)/60)m" }
        return "\(s/60):\(String(format: "%02d", s%60))"
    }

    private var energyLabel: String {
        switch state.context.energyLevel {
        case 8...:  return "peak"
        case 5..<8: return "normal"
        case 3..<5: return "low"
        default:    return "very low"
        }
    }

    // Timeline items from context (placeholder populated by ContextEngine)
    private var todayTimelineItems: [TimelineItem] { [] }

    private func timelineItemColor(_ item: TimelineItem) -> Color {
        if item.isDone { return .white.opacity(0.15) }
        if item.isCurrent { return NT.green }
        switch item.type {
        case "class": return NT.blue
        case "meal":  return NT.amber
        default:      return Color(hex: "#222222")
        }
    }
}

struct TimelineItem: Identifiable {
    var id: UUID = UUID()
    var time: String
    var label: String
    var type: String = "task"
    var isDone: Bool = false
    var isCurrent: Bool = false
}
