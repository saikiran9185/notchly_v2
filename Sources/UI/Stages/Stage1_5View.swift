import SwiftUI

/// Stage 1.5 — Hover preview (Phase C).
/// Shows on mouse hover over idle pill. Expands to ~240×60pt.
struct Stage1_5View: View {

    @EnvironmentObject var state: NotchState

    private let cardW: CGFloat = 240
    private let cardH: CGFloat = 60
    private let radius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.black)
            .frame(width: cardW, height: cardH)
            .overlay(
                hoverContent
            )
            .onHover { inside in
                if !inside {
                    HoverHandler.shared.mouseExited()
                }
            }
    }

    @ViewBuilder
    private var hoverContent: some View {
        if let task = state.currentTask {
            HStack(spacing: 12) {
                Image(systemName: task.category.sfSymbol)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(task.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Button("Open") {
                    state.transition(to: .s2a_nowcard)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#1D9E75"))
            }
            .padding(.horizontal, 14)
        } else {
            Text("Nothing scheduled right now")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
