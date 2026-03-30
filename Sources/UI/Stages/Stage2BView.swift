import SwiftUI

/// Stage 2B — Missed alerts tray (Phase G).
struct Stage2BView: View {

    @EnvironmentObject var state: NotchState

    private let cardW: CGFloat = 340
    private let cardH: CGFloat = 220
    private let radius: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.black)
            .frame(width: cardW, height: cardH)
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider().background(Color.white.opacity(0.1))
                    missedList
                }
                .padding(.vertical, 14)
            )
    }

    private var header: some View {
        HStack {
            Text("Missed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text("(\(state.missedAlerts.count))")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#E44B4A"))
            Spacer()
            Button("Clear all") {
                state.clearAllMissed()
                state.collapseToIdle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var missedList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(state.missedAlerts) { missed in
                    missedRow(missed)
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
    }

    private func missedRow(_ missed: MissedAlert) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: NotifColor.color(for: missed.alert.type)))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(missed.alert.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(missed.timeAgoString)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Button("Do it") {
                ActionEngine.shared.acceptCurrentAlert()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#1D9E75"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
