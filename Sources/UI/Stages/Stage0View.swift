import SwiftUI

/// Stage 0 — Idle state.
///
/// The pill sits BELOW the physical notch hardware (offset handled by NotchRootView).
/// It appears as a small dark bar that drops from the notch edge — visually anchored
/// to the hardware but not clipped by it.
///
/// Dot rules:
///   Deep focus (same app > 20 min):  NO dot. Completely invisible.
///   Missed alerts exist:             dim red dot rgba(228,75,74,0.20)
///   Normal idle:                     dim white dot rgba(255,255,255,0.06)
struct Stage0View: View {

    @EnvironmentObject var state: NotchState

    private var dims: NotchDimensions { NotchDimensions.shared }

    // Pill is same width as physical notch, height is slightly less so it
    // tucks cleanly below the hardware edge without looking disconnected.
    private var pillW: CGFloat { dims.notchW }
    private var pillH: CGFloat { max(dims.notchH - 6, 22) }

    private let topRadius:    CGFloat = 4
    private let bottomRadius: CGFloat = 10

    // Dot color — nil = invisible (deep focus)
    private var dotColor: Color? {
        if state.context.isDeepWork { return nil }
        if !state.missedAlerts.isEmpty {
            return Color(red: 228/255, green: 75/255, blue: 74/255, opacity: 0.20)
        }
        return Color.white.opacity(0.06)
    }

    @State private var appeared = false

    var body: some View {
        AsymmetricRoundedRect(topRadius: topRadius, bottomRadius: bottomRadius)
            .fill(Color(hex: "#0d0d0d"))
            .frame(width: pillW, height: pillH)
            .overlay(
                Group {
                    if let dot = dotColor {
                        Circle()
                            .fill(dot)
                            .frame(width: 3, height: 3)
                    }
                }
            )
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.4)) { appeared = true }
            }
            .onDisappear { appeared = false }
    }
}
