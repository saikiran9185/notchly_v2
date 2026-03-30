import SwiftUI

/// Root view — sits in a 720×480pt canvas centered on the screen.
/// The pill is positioned at the top-center, anchored to the physical notch.
/// Everything grows downward from there.
struct NotchRootView: View {

    @EnvironmentObject var state: NotchState

    private var dims: NotchDimensions { NotchDimensions.shared }

    var body: some View {
        ZStack(alignment: .top) {

            // Stage content
            stageContent
                .frame(maxWidth: .infinity, alignment: .center)

            // Continuity banner — below pill
            if state.showContinuityBanner {
                VStack {
                    Spacer()
                        .frame(height: dims.notchH + 6)
                    ContinuityBanner(
                        message: state.continuityMessage,
                        notchH: dims.notchH
                    )
                    Spacer()
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal:   .move(edge: .top).combined(with: .opacity)
                    )
                )
            }
        }
        // Full canvas — pill MUST be at y=0 (top of window = top of screen = notch)
        // alignment: .top is critical — without it SwiftUI centers the 38pt pill
        // in the 480pt frame, placing it ~220pt below the notch hardware.
        .frame(width: 720, height: 480, alignment: .top)
        .allowsHitTesting(state.stage != .s0_idle)
        // Override: always allow hits on the pill area
        .overlay(
            // Pill hit zone — always interactive
            Color.clear
                .frame(width: dims.notchW + 40, height: dims.notchH + 20)
                .allowsHitTesting(true),
            alignment: .top
        )
        .background(Color.clear)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch state.stage {
        case .s0_idle:
            Stage0View()
                .transition(.opacity)

        case .s1a_notification:
            Stage1AView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal:   .scale(scale: 0.85).combined(with: .opacity)
                ))

        case .s1b_timer:
            Stage1BView()
                .transition(.opacity)

        case .s1_5_hover:
            Stage1_5View()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal:   .scale(scale: 0.9).combined(with: .opacity)
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
            // Diagnosis overlay reuses hover card shape
            Stage1_5View()
                .transition(.opacity)
        }
    }
}
