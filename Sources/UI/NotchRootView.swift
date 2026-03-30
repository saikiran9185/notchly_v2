import SwiftUI

/// Root view — 720×480pt canvas, window top flush with physical notch hardware.
///
/// POSITIONING LOGIC:
///   Window top = screen.frame.maxY (top of MacBook screen = physical notch row)
///   Physical notch hardware occupies y=0 → y=notchH (32pt) from screen top.
///   ALL stage views are offset down by notchH so they appear BELOW the physical
///   camera housing and are fully visible. The hover-zone hit detection (done in
///   global NSEvent coordinates) is unaffected — it still fires from the notch top.
struct NotchRootView: View {

    @EnvironmentObject var state: NotchState
    private var dims: NotchDimensions { NotchDimensions.shared }

    var body: some View {
        ZStack(alignment: .top) {

            // ── Stage pills / cards ──────────────────────────────────────────
            // Offset by notchH so every stage emerges below the physical camera
            // housing. The top notchH pixels of the window are intentionally
            // transparent (the hardware fills that space visually).
            stageContent
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, dims.notchH)     // ← key: clears physical notch

            // ── Continuity banner ────────────────────────────────────────────
            // Appears notchH + 6pt below the window top (just under the notch edge)
            if state.showContinuityBanner {
                ContinuityBanner(
                    message: state.continuityMessage,
                    notchH: dims.notchH
                )
                .padding(.top, dims.notchH + 6)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .frame(width: 720, height: 480, alignment: .top)
        // Click-through when idle (only notch strip stays interactive)
        .allowsHitTesting(state.stage != .s0_idle)
        // Always-interactive hit zone pinned to the notch strip at the top
        .overlay(
            Color.clear
                .frame(width: dims.notchW + 40, height: dims.notchH + 20)
                .allowsHitTesting(true),
            alignment: .top
        )
        .background(Color.clear)
    }

    // MARK: - Stage routing

    @ViewBuilder
    private var stageContent: some View {
        switch state.stage {
        case .s0_idle:
            Stage0View()
                .transition(.opacity)

        case .s1a_notification:
            Stage1AView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal:   .scale(scale: 0.9).combined(with: .opacity)
                ))

        case .s1b_timer:
            Stage1BView()
                .transition(.opacity)

        case .s1_5_hover:
            Stage1_5View()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal:   .scale(scale: 0.95).combined(with: .opacity)
                ))

        case .s2a_nowcard:
            Stage2AView()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))

        case .s2b_missed:
            Stage2BView()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))

        case .s3_dashboard:
            Stage3View()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))

        case .s4_chat:
            Stage4ChatView()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))

        case .s1_5x_diagnosis:
            Stage1_5View()
                .transition(.opacity)
        }
    }
}
