import SwiftUI

struct Stage0View: View {
    @EnvironmentObject var state: NotchState

    @State private var dotOpacity: Double = 0

    var body: some View {
        // Background is drawn by NotchRootView — this view is content-only
        ZStack {
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
            }
        }
        .onDisappear { dotOpacity = 0 }
    }

    private var idleDotColor: Color {
        if !state.missedNotifications.isEmpty {
            return Color(red: 228/255, green: 75/255, blue: 74/255).opacity(0.20)
        }
        return Color.white.opacity(0.06)
    }
}
