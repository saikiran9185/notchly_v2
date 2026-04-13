import SwiftUI

struct Stage2BView: View {
    @EnvironmentObject var state: NotchState
    @State private var expandedID: UUID?

    private var missed: [NotchNotification] {
        Array(state.missedNotifications.suffix(2).reversed())
    }

    private var pillH: CGFloat {
        let base = NotchDimensions.shared.notchH + 20
        let rows = CGFloat(min(2, missed.count))
        let expandedExtra: CGFloat = expandedID != nil ? 30 : 0
        return base + rows * 28 + expandedExtra + 8
    }

    var body: some View {
        // Background drawn by NotchRootView
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Circle().fill(NT.red).frame(width: 5, height: 5)
                Text("MISSED · \(max(state.missedNotifications.count, state.pulseMissedCount))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(NT.red)
                    .tracking(0.6)
                Spacer()
                Button {
                    state.transition(to: .s3_dashboard)
                } label: {
                    Text("see all ↓")
                        .font(.system(size: 10))
                        .foregroundColor(NT.textTertiary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(Springs.missedRemove) { state.clearMissed() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.20))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, NotchDimensions.shared.notchH - 4)
            .padding(.bottom, 8)

            ForEach(missed) { notif in
                missedRow(notif)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: pillH)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: expandedID)
        .onHover { if !$0 { state.collapse() } }
    }

    @ViewBuilder
    private func missedRow(_ notif: NotchNotification) -> some View {
        let isExpanded = expandedID == notif.id
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(missedItemColor(notif))
                    .frame(width: 2.5, height: 16)

                Text(notif.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(NT.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(timeAgo(notif.timestamp))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.20))
            }
            .frame(height: 28)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .onTapGesture { expandedID = isExpanded ? nil : notif.id }

            if isExpanded {
                HStack(spacing: 4) {
                    Button("Done ✓") { resolveMissed(notif, action: "done") }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(NT.green)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#1E9650").opacity(0.15)))
                        .buttonStyle(.plain)

                    Button("Still needed") { resolveMissed(notif, action: "keep") }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(NT.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07)))
                        .buttonStyle(.plain)

                    Button("Skip") { resolveMissed(notif, action: "skip") }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(NT.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.04)))
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 5)
                .frame(height: 30)
            }
        }
    }

    private func missedItemColor(_ notif: NotchNotification) -> Color {
        switch notif.type {
        case .class_:   return NT.blue
        case .task:     return NT.green
        case .break_:   return NT.purple
        case .meal:     return NT.amber
        default:        return NT.gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func resolveMissed(_ notif: NotchNotification, action: String) {
        EpisodicLog.shared.append(action: action, notification: notif, context: state.context)
        withAnimation(Springs.missedRemove) {
            state.missedNotifications.removeAll { $0.id == notif.id }
            expandedID = nil
        }
        if state.missedNotifications.isEmpty { state.collapse() }
    }
}
