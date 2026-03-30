import SwiftUI

/// Custom Shape with different corner radii for top and bottom.
/// Uses AnimatablePair so SwiftUI can interpolate radii during transitions.
struct AsymmetricRoundedRect: Shape, Animatable {

    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius    = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let t = topRadius
        let b = bottomRadius

        // Start at top-left after top-left arc
        path.move(to: CGPoint(x: rect.minX + t, y: rect.minY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))

        // Top-right corner
        path.addArc(center: CGPoint(x: rect.maxX - t, y: rect.minY + t),
                    radius: t,
                    startAngle: .degrees(-90),
                    endAngle:   .degrees(0),
                    clockwise:  false)

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - b))

        // Bottom-right corner
        path.addArc(center: CGPoint(x: rect.maxX - b, y: rect.maxY - b),
                    radius: b,
                    startAngle: .degrees(0),
                    endAngle:   .degrees(90),
                    clockwise:  false)

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + b, y: rect.maxY))

        // Bottom-left corner
        path.addArc(center: CGPoint(x: rect.minX + b, y: rect.maxY - b),
                    radius: b,
                    startAngle: .degrees(90),
                    endAngle:   .degrees(180),
                    clockwise:  false)

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + t))

        // Top-left corner
        path.addArc(center: CGPoint(x: rect.minX + t, y: rect.minY + t),
                    radius: t,
                    startAngle: .degrees(180),
                    endAngle:   .degrees(270),
                    clockwise:  false)

        path.closeSubpath()
        return path
    }
}
