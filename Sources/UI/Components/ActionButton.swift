import SwiftUI

enum ActionButtonStyle {
    case primary    // bg=#4A90E2 text=white
    case secondary  // bg=rgba(255,255,255,0.07) text=rgba(255,255,255,0.70) border
    case muted      // bg=rgba(255,255,255,0.05) text=rgba(255,255,255,0.55) border
    case danger     // bg=#E24B4A text=white (deadline escalated)
}

struct ActionButton: View {
    let label: String
    let style: ActionButtonStyle
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 25)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(bgColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(borderColor, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered in isHovered = hovered }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var bgColor: Color {
        switch style {
        case .primary:   return NT.blue
        case .secondary: return Color.white.opacity(isHovered ? 0.10 : 0.07)
        case .muted:     return Color.white.opacity(0.05)
        case .danger:    return NT.red
        }
    }

    private var textColor: Color {
        switch style {
        case .primary, .danger: return .white
        case .secondary:        return Color.white.opacity(0.70)
        case .muted:            return Color.white.opacity(0.55)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary, .danger: return .clear
        case .secondary:        return Color.white.opacity(0.07)
        case .muted:            return Color.white.opacity(0.06)
        }
    }
}
