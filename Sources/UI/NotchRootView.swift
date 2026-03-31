import SwiftUI

// Root view hosted in NotchPanel.
// Canvas: 720×480pt. Origin (0,0) = top of screen = physical notch location.
// All pill content is anchored to the TOP of this canvas.
struct NotchRootView: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let notchW: CGFloat = NotchDimensions.shared.notchW

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent canvas
            Color.clear
                .frame(width: NotchWindowController.WIN_W,
                       height: NotchWindowController.WIN_H)

            // Pill + continuity banner, centered horizontally
            VStack(spacing: 0) {
                // Pill content — switches between stages
                pillContent
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 0)   // pill flush to top = flush to notch

                // Continuity banner — appears 6pt below pill
                if state.showContinuityBanner {
                    ContinuityBanner(message: state.continuityMessage)
                        .padding(.top, 6)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .move(edge: .top).combined(with: .opacity)
                            )
                        )
                }

                Spacer()
            }
        }
        .frame(width: NotchWindowController.WIN_W,
               height: NotchWindowController.WIN_H)
    }

    @ViewBuilder
    private var pillContent: some View {
        switch state.stage {
        case .s0_idle:
            Stage0View()
                .transition(.opacity)

        case .s1a_notification:
            SwipeCardView {
                Stage1AView()
            }
            .transition(.move(edge: .top).combined(with: .opacity))

        case .s1b_timer:
            Stage1BView()
                .transition(.move(edge: .top).combined(with: .opacity))

        case .s1_5_hover:
            Stage15View()
                .transition(.opacity)

        case .s2a_nowcard:
            Stage2AView()
                .transition(.move(edge: .top).combined(with: .opacity))

        case .s2b_missed:
            Stage2BView()
                .transition(.move(edge: .top).combined(with: .opacity))

        case .s3_dashboard:
            Stage3View()
                .transition(.move(edge: .top).combined(with: .opacity))

        case .s4_chat:
            Stage4View()
                .transition(.move(edge: .top).combined(with: .opacity))

        case .s1_5x_diagnosis:
            DiagnosisPillView()
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
