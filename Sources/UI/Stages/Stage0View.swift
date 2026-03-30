import SwiftUI

/// Stage 0 — Idle pill. Exactly matches physical notch dimensions.
/// Dot behavior:
///   - Deep focus (same app >20min):  NO dot. Truly invisible.
///   - Missed alerts exist:           rgba(228,75,74, 0.20)  dim red
///   - Normal idle:                   rgba(255,255,255, 0.06) dim white
struct Stage0View: View {

    @EnvironmentObject var state: NotchState
    @State private var opacity: Double = 0

    private var dims: NotchDimensions { NotchDimensions.shared }

    private var pillW: CGFloat { dims.notchW }
    private var pillH: CGFloat { dims.notchH }

    private var dotColor: Color? {
        if state.context.isDeepWork { return nil }
        if !state.missedAlerts.isEmpty {
            return Color(red: 228/255, green: 75/255, blue: 74/255).opacity(0.20)
        }
        return Color.white.opacity(0.06)
    }

    // Seam masker width = pillW minus topRadius × 2
    private let topRadius: CGFloat = 6
    private let bottomRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .top) {

            // Seam masker — closes gap between pill top-radius and hardware notch
            Rectangle()
                .fill(Color.black)
                .frame(width: pillW - topRadius * 2, height: 2)
                .offset(y: -1)

            // Pill body
            AsymmetricRoundedRect(topRadius: topRadius, bottomRadius: bottomRadius)
                .fill(Color.black)
                .frame(width: pillW, height: pillH)
                .overlay(
                    // Dot — centered in pill
                    Group {
                        if let dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 3, height: 3)
                        }
                    }
                )
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1
            }
        }
    }
}
