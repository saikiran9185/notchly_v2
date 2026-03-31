import SwiftUI

// Custom Shape with different top vs bottom corner radii.
// Uses AnimatablePair so SwiftUI can smoothly interpolate during stage transitions.
struct AsymmetricRoundedRect: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = min(topRadius, rect.width / 2, rect.height / 2)
        let br = min(bottomRadius, rect.width / 2, rect.height / 2)

        // Start at top-left after corner
        path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        // Top edge →
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        // Top-right corner
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr,
                    startAngle: .degrees(-90), endAngle: .degrees(0),
                    clockwise: false)
        // Right edge ↓
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        // Bottom-right corner
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br,
                    startAngle: .degrees(0), endAngle: .degrees(90),
                    clockwise: false)
        // Bottom edge ←
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        // Bottom-left corner
        path.addArc(center: CGPoint(x: rect.minX + br, y: rect.maxY - br),
                    radius: br,
                    startAngle: .degrees(90), endAngle: .degrees(180),
                    clockwise: false)
        // Left edge ↑
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        // Top-left corner
        path.addArc(center: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                    radius: tr,
                    startAngle: .degrees(180), endAngle: .degrees(-90),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
