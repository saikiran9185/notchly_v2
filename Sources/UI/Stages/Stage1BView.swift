import SwiftUI

struct Stage1BView: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    @State private var isHovered: Bool = false
    @State private var timeUpButtonsVisible: Bool = false
    @State private var timeUpTimer: Timer?
    @State private var countdownTimer: Timer?

    private var pillH: CGFloat { isHovered ? notchH + 44 : notchH + 22 }
    private var task: NotchTask? { state.activeTimerTask }

    var body: some View {
        ZStack(alignment: .top) {
            AsymmetricRoundedRect(topRadius: StageRadii.s1.top,
                                  bottomRadius: StageRadii.s1.bottom)
                .fill(NT.surface)
                .overlay(
                    AsymmetricRoundedRect(topRadius: StageRadii.s1.top,
                                         bottomRadius: StageRadii.s1.bottom)
                        .stroke(NT.borderNormal, lineWidth: 0.5)
                )

            VStack(spacing: 0) {
                timerRow
                if isHovered || timeUpButtonsVisible { hoverContent }
            }
            .padding(.horizontal, 14)
            .padding(.top, notchH - 4)
            .padding(.bottom, 8)
        }
        .frame(width: pillWidth, height: pillH)
        .animation(Springs.hoverExpand, value: isHovered)
        .onHover { hovered in isHovered = hovered }
        .onAppear { startCountdown() }
        .onDisappear {
            countdownTimer?.invalidate()
            timeUpTimer?.invalidate()
        }
    }

    // MARK: - Timer row
    private var timerRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(NT.green)
                .frame(width: 5, height: 5)

            Text(task?.title ?? "Task")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(NT.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 10)

            // Tappable timer display
            VStack(spacing: 0) {
                Text(timerDisplay)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(timerColor)

                // Underline on hover
                if isHovered {
                    Rectangle()
                        .fill(NT.green)
                        .frame(height: 0.5)
                        .padding(.top, 1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                togglePause()
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .generic, performanceTime: .now)
            }
            .padding(8)   // hit expansion
        }
    }

    // MARK: - Hover content
    private var hoverContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Text("← Done")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.18))
                Text("  ·  Take break →")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(NT.green.opacity(0.45))
            }

            HStack(spacing: 5) {
                ActionButton(label: "Done ✓", style: .primary) { markDone() }
                ActionButton(label: timeUpButtonsVisible ? "+15 min" : "Take break",
                             style: .secondary) {
                    if timeUpButtonsVisible { extendTimer(by: 15) }
                    else { takeBreak() }
                }
            }
            .frame(height: 25)
        }
        .padding(.top, 6)
    }

    // MARK: - Timer logic
    private var timerDisplay: String {
        let s = state.timerSecondsLeft
        if state.timerIsPaused {
            return formatTime(s) + " ⏸"
        }
        if s <= 0 { return "0:00" }
        if s > 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            return "\(h)h \(m)m"
        }
        return formatTime(s)
    }

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    private var timerColor: Color {
        if state.timerIsPaused { return NT.textSecondary }
        if state.timerSecondsLeft <= 0 {
            return NT.amber
        }
        return NT.green
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !state.timerIsPaused else { return }
            if state.timerSecondsLeft > 0 {
                state.timerSecondsLeft -= 1
            } else {
                onTimeUp()
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func togglePause() {
        state.timerIsPaused.toggle()
    }

    private func onTimeUp() {
        countdownTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.5)) { _ = timerColor }
        state.showContinuity("\(task?.title ?? "Task") time's up")
        timeUpButtonsVisible = true
        timeUpTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            timeUpButtonsVisible = false
        }
    }

    private func markDone() {
        guard let t = task else { return }
        EpisodicLog.shared.append(action: "done", notification: nil, context: state.context, task: t)
        state.showContinuity("\(t.title) done · \(nextLabel()) loading")
        state.activeTimerTask = nil
        state.timerSecondsLeft = 0
        state.collapse()
    }

    private func extendTimer(by minutes: Int) {
        state.timerSecondsLeft += minutes * 60
        state.timerIsPaused = false
        timeUpButtonsVisible = false
        startCountdown()
        state.showContinuity("+\(minutes)m added · \(formatTime(state.timerSecondsLeft)) remaining")
    }

    private func takeBreak() {
        state.showContinuity("Break started · resumes soon")
        state.collapse()
    }

    private func nextLabel() -> String {
        state.taskQueue.first?.title ?? "next task"
    }

    private var pillWidth: CGFloat { min(360, max(280, 320)) }
}
