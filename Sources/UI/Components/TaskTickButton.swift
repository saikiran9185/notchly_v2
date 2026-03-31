import SwiftUI

// 14×14pt circle tick button used in Stage 3 task list
struct TaskTickButton: View {
    let isDone: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if !isDone { action() }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(borderColor, lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(isDone ? Color(hex: "#1E9650").opacity(0.20) : .clear)
                    )

                if isDone {
                    // Checkmark: 5×6pt stroke path
                    Path { path in
                        path.move(to: CGPoint(x: 4, y: 7))
                        path.addLine(to: CGPoint(x: 6, y: 9))
                        path.addLine(to: CGPoint(x: 10, y: 5))
                    }
                    .stroke(NT.green, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovered }
        }
    }

    private var borderColor: Color {
        if isDone { return NT.green }
        return isHovered ? NT.green : Color.white.opacity(0.15)
    }
}
