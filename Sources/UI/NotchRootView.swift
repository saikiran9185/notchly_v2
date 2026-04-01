import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject var state: NotchState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(width: NotchWindowController.WIN_W,
                       height: NotchWindowController.WIN_H)

            VStack(spacing: 0) {
                pillContent
                    .frame(maxWidth: .infinity, alignment: .center)

                if state.showContinuityBanner {
                    ContinuityBanner(message: state.continuityMessage)
                        .padding(.top, 6)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }

                Spacer()
            }
        }
        .frame(width: NotchWindowController.WIN_W,
               height: NotchWindowController.WIN_H)
    }

    private var pillContent: some View {
        let layout = NotchlyLayout(progress: state.displayProgress)
        let isMeal = state.currentNotification?.type == .meal

        return ZStack(alignment: .top) {
            // Single background layer — the ONLY place NT.surface is drawn
            AsymmetricRoundedRect(
                topRadius: layout.topRadius,
                bottomRadius: layout.bottomRadius
            )
            .fill(isMeal ? NT.green.opacity(0.08) : NT.surface)
            .overlay(
                AsymmetricRoundedRect(
                    topRadius: layout.topRadius,
                    bottomRadius: layout.bottomRadius
                )
                .stroke(
                    isMeal ? NT.green.opacity(0.25) : Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
            )
            .frame(width: layout.width, height: layout.height)
            .scaleEffect(layout.contentScale, anchor: .top)
            .shadow(
                color: .black.opacity(layout.shadowOpacity),
                radius: layout.shadowRadius,
                y: layout.shadowY
            )

            VStack(spacing: 0) {
                contentForStage
                    .opacity(1.0)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, NotchDimensions.shared.notchH - 4)
                    .padding(.bottom, layout.bottomPadding)
            }
            .frame(width: layout.width)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: state.scrollProgress)
    }

    @ViewBuilder
    private var contentForStage: some View {
        switch state.stage {
        case .s0_idle:
            Stage0View()
                .transition(.opacity)

        case .s1a_notification:
            SwipeCardView { Stage1AView() }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s1b_timer:
            Stage1BView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s1_5_hover:
            Stage15View()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s2a_nowcard:
            Stage2AView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s2b_missed:
            Stage2BView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s3_dashboard:
            Stage3View()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s4_chat:
            Stage4View()
                .opacity(NotchMath.smoothstep(state.scrollProgress - 0.7))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))

        case .s1_5x_diagnosis:
            DiagnosisPillView()
                .padding(.top, 40)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)))
        }
    }
}
