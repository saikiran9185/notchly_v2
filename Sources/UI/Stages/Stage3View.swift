import SwiftUI

struct Stage3View: View {
    @EnvironmentObject var state: NotchState

    @State private var completedIDs: Set<UUID> = []
    @State private var currentPulse: Bool = false
    @State private var showHowTo: Bool = false

    private let sectionBg    = Color.white.opacity(0.025)
    private let sectionBorder = Color.white.opacity(0.04)

    var body: some View {
        // Background drawn by NotchRootView
        VStack(spacing: 8) {
            // Row 1: Timeline | Tasks Left
            HStack(spacing: 6) {
                timelineCard.frame(maxWidth: .infinity).frame(minWidth: 0)
                tasksCard.frame(maxWidth: .infinity).frame(minWidth: 0)
            }

            // Row 2: Now+Prep | Day Score
            HStack(spacing: 6) {
                nowPrepCard
                dayScoreCard
            }

            // Full-width chat hint
            chatHintBar

            // How to Use collapsible section
            howToUseSection
        }
        .padding(.horizontal, 12)
        .padding(.top, NotchDimensions.shared.notchH + 12)
        .padding(.bottom, 14)
        // contentShape expands hit-testing to include top padding (hover zone area)
        // so double-tap fires even when tapped near the notch edge
        .contentShape(Rectangle())
        // Collapse handled by HoverZoneMonitor — no onHover here
        .gesture(TapGesture(count: 2).onEnded {
            withAnimation(Springs.expand) {
                state.rawProgress     = 1.0
                state.displayProgress = 1.0
                state.scrollProgress  = 1.0
            }
            state.transition(to: .s4_chat, spring: Springs.expand)
        })
    }

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

    private var timelineCard: some View {
        sectionCard("TODAY") {
            VStack(spacing: 0) {
                ForEach(todayTimelineItems.prefix(6), id: \.id) { item in
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

    private var tasksCard: some View {
        sectionCard("TASKS · tap ✓ to mark done") {
            VStack(spacing: 0) {
                ForEach(state.taskQueue.prefix(5)) { task in
                    HStack(spacing: 6) {
                        TaskTickButton(isDone: completedIDs.contains(task.id)) {
                            withAnimation(Springs.missedRemove) { completedIDs.insert(task.id) }
                            EpisodicLog.shared.append(action: "done", notification: nil, context: state.context, task: task)
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

    private var howToUseSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showHowTo.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showHowTo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))
                    Text("how to use")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if showHowTo {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(howToSteps.enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 6) {
                            Text(step.0)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                                .frame(width: 16, alignment: .trailing)
                            Text(step.1)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        )
    }

    private let howToSteps: [(String, String)] = [
        ("1", "hover notch → pill shows your current task with timer"),
        ("2", "scroll down slowly → NowCard expands with 3 action buttons"),
        ("3", "scroll more → full dashboard with today's timeline & queue"),
        ("4", "double-tap dashboard → chat opens to add tasks or ask anything"),
        ("5", "swipe left/right on any notification → skip it or mark done"),
    ]

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

    private var todayTimelineItems: [TimelineItem] {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let now = Date()
        return state.taskQueue.prefix(6).compactMap { task -> TimelineItem? in
            guard let start = task.scheduledStart else { return nil }
            let isCurrent = start <= now && (task.deadline.map { $0 >= now } ?? true)
            return TimelineItem(
                time: fmt.string(from: start),
                label: task.title,
                type: task.category.rawValue,
                isDone: task.isCompleted,
                isCurrent: isCurrent
            )
        }
    }

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
