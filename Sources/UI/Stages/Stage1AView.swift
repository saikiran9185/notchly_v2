import SwiftUI

struct Stage1AView: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    @State private var isHovered: Bool = false
    @State private var dotOpacity: Double = 0
    @State private var dismissTimer: Timer?
    @State private var swipeHintShown: Bool = UserDefaults.standard.bool(forKey: "notchly_swipe_hint_shown")

    // Width formula: max(240, min(400, textWidth + dot(5) + sep(1) + subW + hpad(28)))
    // We use content-fit with min/max clamping via frame modifiers
    private let minW: CGFloat = 240
    private let maxW: CGFloat = 400
    private var pillH: CGFloat { isHovered ? notchH + 44 : notchH + 20 }

    private var notification: NotchNotification? { state.currentNotification }

    var body: some View {
        ZStack(alignment: .top) {
            // Pill background
            AsymmetricRoundedRect(topRadius: StageRadii.s1.top,
                                  bottomRadius: StageRadii.s1.bottom)
                .fill(NT.surface)
                .overlay(
                    AsymmetricRoundedRect(topRadius: StageRadii.s1.top,
                                         bottomRadius: StageRadii.s1.bottom)
                        .stroke(NT.borderNormal, lineWidth: 0.5)
                )

            VStack(spacing: 0) {
                // Default row (always visible)
                titleRow

                // Hover expansion: hint text + action buttons
                if isHovered {
                    hintAndButtons
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, notchH - 4)
            .padding(.bottom, 8)

            // Swipe affordance (first-run only)
            if !swipeHintShown && !isHovered {
                swipeAffordanceNudge
            }
        }
        .frame(width: pillWidth, height: pillH)
        .animation(Springs.hoverExpand, value: isHovered)
        .onHover { hovered in
            isHovered = hovered
            if hovered {
                dismissTimer?.invalidate()
            } else {
                restartDismissTimer()
            }
        }
        .onAppear {
            restartDismissTimer()
            triggerSwipeNudgeIfNeeded()
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }

    // MARK: - Title row
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

    // MARK: - Hover: hint + buttons
    private var hintAndButtons: some View {
        VStack(spacing: 6) {
            // Hint text: "← [leftAction]  ·  [rightAction] →"
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

                // Action buttons slide down from inside bar
                HStack(spacing: 5) {
                    ActionButton(label: notif.leftAction, style: .secondary) {
                        performLeft()
                    }
                    ActionButton(label: notif.rightAction, style: .primary) {
                        performRight()
                    }
                }
                .frame(height: 25)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Swipe hint nudge (fires once per install)
    @State private var nudgeOffset: CGFloat = 0
    private var swipeAffordanceNudge: some View {
        Color.clear
            .offset(x: nudgeOffset)
    }

    private func triggerSwipeNudgeIfNeeded() {
        guard !swipeHintShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(Springs.nudge) { nudgeOffset = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(Springs.nudge) { nudgeOffset = -10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(Springs.nudge) { nudgeOffset = 0 }
                    UserDefaults.standard.set(true, forKey: "notchly_swipe_hint_shown")
                    swipeHintShown = true
                }
            }
        }
    }

    // MARK: - Actions
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
        min(maxW, max(minW, 300))  // content-fit — refined in Phase D
    }

    private func nextTaskLabel() -> String {
        state.taskQueue.first?.title ?? "loading"
    }

    private func continuityMessage(for notif: NotchNotification, action: SwipeDirection) -> String {
        switch (notif.type, action) {
        case (.meal, .right):   return "Noted · mess closes in \(messClosingMinutes())m"
        case (.meal, .left):    return "Skipping lunch · energy adjusted"
        case (.class_, .right): return "On your way · class soon"
        case (.task, .right):   return "\(notif.title) done · \(nextTaskLabel()) loading"
        default:                return "\(notif.title) done · \(nextTaskLabel()) loading"
        }
    }

    private func messClosingMinutes() -> Int { 30 }  // refined by CalendarReader
}

enum SwipeDirection { case left, right }
