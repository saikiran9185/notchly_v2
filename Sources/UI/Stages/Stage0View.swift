import SwiftUI

struct Stage0View: View {
    @EnvironmentObject var state: NotchState

    // Cached once, not re-read in body
    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let notchW: CGFloat = NotchDimensions.shared.notchW

    @State private var dotOpacity: Double = 0

    var body: some View {
        ZStack {
            // Pill — pure black, anchored to notch
            AsymmetricRoundedRect(topRadius: StageRadii.s0.top,
                                  bottomRadius: StageRadii.s0.bottom)
                .fill(Color.black)
                .frame(width: notchW, height: notchH)

            // Seam masker — closes visual gap at notch top edge
            // width = pillW − topRadius × 2
            Rectangle()
                .fill(Color.black)
                .frame(width: notchW - StageRadii.s0.top * 2, height: 2)
                .offset(y: -(notchH / 2 + 1))

            // Idle dot — 3×3pt, centered, fades in over 0.4s
            if !state.isDeepFocus {
                Circle()
                    .fill(idleDotColor)
                    .frame(width: 3, height: 3)
                    .opacity(dotOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.4)) {
                            dotOpacity = 1.0
                        }
                    }
                    .onChange(of: state.missedNotifications.count) { _ in
                        // Dot color reacts to missed count; no opacity reset needed
                    }
            }
        }
        .frame(width: notchW, height: notchH)
        .onDisappear { dotOpacity = 0 }
    }

    // Deep focus → invisible (no dot)
    // Missed alerts → dim red
    // Normal → dim white
    private var idleDotColor: Color {
        if !state.missedNotifications.isEmpty {
            return Color(red: 228/255, green: 75/255, blue: 74/255).opacity(0.20)
        }
        return Color.white.opacity(0.06)
    }
}
