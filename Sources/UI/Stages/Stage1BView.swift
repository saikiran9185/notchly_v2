import SwiftUI

/// Stage 1B — Focus timer pill (Phase E).
struct Stage1BView: View {

    @EnvironmentObject var state: NotchState
    private let dims = NotchDimensions.shared

    private let pillW: CGFloat = 200
    private let pillH: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: pillH / 2)
            .fill(Color.black)
            .frame(width: pillW, height: pillH)
            .overlay(
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.timerIsPaused ? Color.orange : Color(hex: "#1D9E75"))
                        .frame(width: 6, height: 6)

                    Text(formattedTime)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white)

                    Text(state.timerTaskName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
            )
    }

    private var formattedTime: String {
        let m = state.timerSecondsRemaining / 60
        let s = state.timerSecondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
