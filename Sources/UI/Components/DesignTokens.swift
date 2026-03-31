import SwiftUI

// MARK: - Color hex initializer
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Design tokens
enum NT {
    // Backgrounds
    static let background  = Color(hex: "#0d0d0d")
    static let surface     = Color(hex: "#111111")
    static let surface2    = Color(hex: "#161616")

    // Borders
    static let borderNormal = Color.white.opacity(0.07)
    static let borderHover  = Color.white.opacity(0.12)
    static let borderActive = Color.white.opacity(0.18)

    // Text
    static let textPrimary    = Color.white.opacity(0.90)
    static let textSecondary  = Color.white.opacity(0.45)
    static let textTertiary   = Color.white.opacity(0.22)
    static let textMuted      = Color.white.opacity(0.10)

    // Semantic
    static let green      = Color(hex: "#1D9E75")
    static let greenDim   = Color(hex: "#1D9E75").opacity(0.35)
    static let amber      = Color(hex: "#BA7517")
    static let red        = Color(hex: "#E24B4A")
    static let blue       = Color(hex: "#4A90E2")
    static let purple     = Color(hex: "#7F77DD")
    static let coral      = Color(hex: "#D85A30")
    static let gray       = Color(hex: "#5F5E5A")

    // Swipe washes
    static func swipeRightWash(_ ratio: Double) -> Color {
        Color(hex: "#1D9E75").opacity(ratio * 0.55)
    }
    static func swipeLeftWash(_ ratio: Double) -> Color {
        Color(red: 80/255, green: 80/255, blue: 80/255).opacity(ratio * 0.40)
    }
}

// MARK: - Animation springs
enum Springs {
    static let pill       = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let expand     = Animation.spring(response: 0.50, dampingFraction: 0.88)
    static let hoverExpand = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let collapse   = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let nudge      = Animation.spring(response: 0.28, dampingFraction: 0.65)
    static let snapBack   = Animation.spring(response: 0.32, dampingFraction: 0.68)
    static let continuity = Animation.spring(response: 0.45, dampingFraction: 0.72)
    static let chat       = Animation.spring(response: 0.40, dampingFraction: 0.80)
    static let missedRemove = Animation.spring(response: 0.28, dampingFraction: 0.78)
}

// MARK: - Corner radii per stage
struct StageRadii {
    let top: CGFloat
    let bottom: CGFloat

    static let s0   = StageRadii(top: 6,  bottom: 10)
    static let s1   = StageRadii(top: 8,  bottom: 14)
    static let s1_5 = StageRadii(top: 10, bottom: 16)
    static let s2   = StageRadii(top: 12, bottom: 20)
    static let s3   = StageRadii(top: 16, bottom: 24)
    static let s4   = StageRadii(top: 16, bottom: 24)
}

// MARK: - Notif type dot color
extension NotifType {
    var dotColor: Color {
        switch self {
        case .meal:      return NT.amber
        case .task:      return NT.green
        case .class_:    return NT.blue
        case .exercise:  return NT.green
        case .deadline:  return NT.red
        case .lazy:      return NT.coral
        case .break_:    return NT.purple
        default:         return NT.gray
        }
    }
}
