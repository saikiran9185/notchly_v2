import SwiftUI

/// Stage 3 — Dashboard (Phase H).
/// Full notch expansion showing today's task queue, energy bar, upcoming events.
struct Stage3View: View {

    @EnvironmentObject var state: NotchState

    private let cardW: CGFloat = 520
    private let cardH: CGFloat = 320
    private let radius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
            .frame(width: cardW, height: cardH)
            .overlay(
                HStack(alignment: .top, spacing: 0) {
                    // Left: task queue
                    leftPanel
                        .frame(width: cardW * 0.55)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Right: today summary
                    rightPanel
                        .frame(width: cardW * 0.45)
                }
                .padding(.vertical, 18)
            )
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { v in
                        if v.translation.height < -40 {
                            state.collapseToIdle()
                        }
                    }
            )
    }

    // MARK: - Panels

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up next")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 18)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(state.taskQueue.prefix(6)) { task in
                        taskRow(task)
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            energySection
            Divider().background(Color.white.opacity(0.1))
            contextSection
        }
        .padding(.horizontal, 16)
    }

    private func taskRow(_ task: NotchTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.category.sfSymbol)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(task.durationMinutes)m · P\(String(format: "%.1f", task.pScore))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Energy")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < Int(state.context.energyLevel)
                              ? Color(hex: "#1D9E75")
                              : Color.white.opacity(0.1))
                        .frame(height: 16)
                }
            }

            Text(String(format: "%.1f / 10", state.context.energyLevel))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            contextRow(icon: "clock", label: "Hour", value: "\(state.context.hour):00")
            contextRow(icon: "app.badge", label: "App", value: state.context.frontmostApp.components(separatedBy: ".").last ?? "—")
            contextRow(icon: "exclamationmark.triangle", label: "Missed", value: "\(state.missedAlerts.count)")
        }
    }

    private func contextRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
