import SwiftUI

/// Stage 2A — NowCard (Phase F).
/// Full task card with progress arc, energy bar, action buttons.
struct Stage2AView: View {

    @EnvironmentObject var state: NotchState

    private let cardW: CGFloat = 360
    private let cardH: CGFloat = 180
    private let radius: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.black)
            .frame(width: cardW, height: cardH)
            .overlay(
                VStack(alignment: .leading, spacing: 14) {
                    if let task = state.currentTask {
                        taskHeader(task)
                        progressRow(task)
                        actionRow(task)
                    } else {
                        Text("No task in focus")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(18)
            )
    }

    // MARK: - Components

    private func taskHeader(_ task: NotchTask) -> some View {
        HStack {
            Image(systemName: task.category.sfSymbol)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !task.subtitle.isEmpty {
                    Text(task.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { state.collapseToIdle() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    private func progressRow(_ task: NotchTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(Int(task.progressPct * 100))% complete")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(task.durationMinutes)m")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "#1D9E75"))
                        .frame(width: g.size.width * task.progressPct, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func actionRow(_ task: NotchTask) -> some View {
        HStack(spacing: 10) {
            Button("Postpone") {
                ActionEngine.shared.postponeTask(task)
            }
            .buttonStyle(NotchButtonStyle(tint: .secondary))

            Spacer()

            Button("Done") {
                ActionEngine.shared.taskCompleted(task: task)
            }
            .buttonStyle(NotchButtonStyle(tint: .primary))
        }
    }
}

// MARK: - NotchButtonStyle

enum NotchButtonTint { case primary, secondary }

struct NotchButtonStyle: ButtonStyle {
    var tint: NotchButtonTint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: tint == .primary ? .semibold : .regular))
            .foregroundColor(tint == .primary ? Color(hex: "#1D9E75") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
