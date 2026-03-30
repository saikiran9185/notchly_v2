import SwiftUI

/// Stage 1A — Notification card (Phase D).
/// Shows when a new alert fires. Expands pill to ~280×72pt.
/// Swipe right = accept, left = dismiss.
struct Stage1AView: View {

    @EnvironmentObject var state: NotchState
    private let dims = NotchDimensions.shared

    // Card dimensions
    private let cardW: CGFloat = 280
    private let cardH: CGFloat = 72
    private let radius: CGFloat = 18

    var body: some View {
        ZStack {
            // Card body
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.black)
                .frame(width: cardW + state.swipeXOffset * 0.4, height: cardH)
                .overlay(
                    // Green wash (accept)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color(hex: "#1D9E75").opacity(state.swipeGreenWashOpacity))
                )
                .overlay(
                    // Gray wash (dismiss)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color.gray.opacity(state.swipeGrayWashOpacity))
                )

            if let alert = state.currentAlert {
                HStack(spacing: 12) {
                    // Left action button
                    Button(action: { ActionEngine.shared.dismissCurrentAlert() }) {
                        Text(alert.leftAction)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(state.swipeLeftBtnScale)

                    Spacer()

                    VStack(alignment: .center, spacing: 3) {
                        Text(alert.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(alert.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Right action button
                    Button(action: { ActionEngine.shared.acceptCurrentAlert() }) {
                        Text(alert.rightAction)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#1D9E75"))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(state.swipeRightBtnScale)
                }
                .padding(.horizontal, 16)
            }
        }
        .offset(x: state.swipeXOffset * 0.4)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { v in
                    SwipeHandler.shared.handleDrag(
                        translation: v.translation.width,
                        velocity: v.velocity.width
                    )
                }
                .onEnded { v in
                    SwipeHandler.shared.handleDragEnded(
                        translation: v.translation.width,
                        velocity: v.velocity.width
                    )
                }
        )
    }
}
