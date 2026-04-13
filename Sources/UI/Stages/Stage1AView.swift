import SwiftUI

struct Stage1AView: View {
    @EnvironmentObject var state: NotchState

    @State private var isHovered: Bool = false
    @State private var dotOpacity: Double = 0
    @State private var dismissTimer: Timer?
    @State private var swipeHintShown: Bool = UserDefaults.standard.bool(forKey: "notchly_swipe_hint_shown")

    private let minW: CGFloat = 240
    private let maxW: CGFloat = 400
    private var pillH: CGFloat { isHovered ? NotchDimensions.shared.notchH + 44 : NotchDimensions.shared.notchH + 20 }

    private var notification: NotchNotification? { state.currentNotification }

    var body: some View {
        // Background drawn by NotchRootView (meal wash included there)
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                titleRow

                if isHovered {
                    hintAndButtons
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, NotchDimensions.shared.notchH - 4)
            .padding(.bottom, 8)

            if !swipeHintShown && !isHovered {
                swipeAffordanceNudge
            }
        }
        .frame(width: pillWidth, height: pillH)
        .offset(x: nudgeOffset)
        .animation(Springs.hoverExpand, value: isHovered)
        .onHover { hovered in
            isHovered = hovered
            if hovered { dismissTimer?.invalidate() }
            else { restartDismissTimer() }
        }
        .onAppear { restartDismissTimer(); triggerSwipeNudgeIfNeeded() }
        .onDisappear { dismissTimer?.invalidate() }
    }

    private var titleRow: some View {
        HStack(spacing: 7) {
            if let notif = notification {
                Circle()
                    .fill(notif.type.dotColor)
                    .frame(width: 5, height: 5)

                Text(notif.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NT.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 10)

                Text(notif.subtitle)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(NT.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var hintAndButtons: some View {
        VStack(spacing: 6) {
            if let notif = notification {
                HStack(spacing: 0) {
                    Text("← \(notif.leftAction)")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.18))
                    Text("  ·  ")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.12))
                    Text("\(notif.rightAction) →")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(NT.green.opacity(0.45))
                }

                HStack(spacing: 5) {
                    ActionButton(label: notif.leftAction, style: .secondary) { performLeft() }
                    ActionButton(label: notif.rightAction, style: .primary) { performRight() }
                }
                .frame(height: 25)
            }
        }
        .padding(.top, 6)
    }

    @State private var nudgeOffset: CGFloat = 0

    // Arrow indicators that fade in during the nudge to hint swipe direction
    private var swipeAffordanceNudge: some View {
        HStack {
            Text("←").font(.system(size: 10, weight: .light)).foregroundColor(.white.opacity(0.20))
            Spacer()
            Text("→").font(.system(size: 10, weight: .light)).foregroundColor(NT.green.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .offset(y: NotchDimensions.shared.notchH + 6)
    }

    private func triggerSwipeNudgeIfNeeded() {
        guard !swipeHintShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(Springs.nudge) { nudgeOffset = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(Springs.nudge) { nudgeOffset = -12 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(Springs.nudge) { nudgeOffset = 0 }
                    UserDefaults.standard.set(true, forKey: "notchly_swipe_hint_shown")
                    swipeHintShown = true
                }
            }
        }
    }

    private func performRight() {
        guard let notif = notification else { return }
        EpisodicLog.shared.append(action: "swipe_right", notification: notif, context: state.context)
        EVRUpdater.shared.recordPrimary(for: notif)
        state.showContinuity(continuityMessage(for: notif, action: .right))
        state.currentNotification = nil
        state.collapse()
    }

    private func performLeft() {
        guard let notif = notification else { return }
        EpisodicLog.shared.append(action: "skip", notification: notif, context: state.context)
        EVRUpdater.shared.recordDismissed(for: notif)
        state.showContinuity("Skipped · \(nextTaskLabel())")

        if let idx = state.taskQueue.firstIndex(where: {
            $0.title == notif.title || $0.id == notif.task?.id
        }) {
            state.taskQueue[idx].rejectionCount += 1
            var task = state.taskQueue[idx]
            BDIAgent.shared.checkDiagnosisMode(for: task, state: state)
        }

        state.dismissCurrentNotification()
    }

    private func restartDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            guard let notif = self.notification else { return }
            EpisodicLog.shared.append(action: "ignored", notification: notif, context: self.state.context)
            EVRUpdater.shared.recordIgnored(for: notif)
            self.state.dismissCurrentNotification()
        }
    }

    private var pillWidth: CGFloat {
        min(maxW, max(minW, 300))
    }

    private func nextTaskLabel() -> String {
        // Skip completed tasks and the notification's own task to find the real next item
        state.taskQueue.first(where: { !$0.isCompleted && $0.title != notification?.title })?.title ?? ""
    }

    private func continuityMessage(for notif: NotchNotification, action: SwipeDirection) -> String {
        switch (notif.type, action) {
        case (.meal, .right):   return "Noted · mess closes in \(messClosingMinutes())m"
        case (.meal, .left):    return "Skipping lunch · energy adjusted"
        case (.class_, .right): return "On your way · class soon"
        case (.task, .right):
            let next = nextTaskLabel()
            return next.isEmpty ? "\(notif.title) done" : "\(notif.title) done · \(next) up next"
        default:
            let next = nextTaskLabel()
            return next.isEmpty ? "\(notif.title) done" : "\(notif.title) done · \(next) up next"
        }
    }

    private func messClosingMinutes() -> Int { 30 }
}

enum SwipeDirection { case left, right }
