import SwiftUI

/// Confirmation banner that appears below the pill for 4 seconds after any action.
struct ContinuityBanner: View {

    let message: String
    let notchH: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: "#1D9E75"))
                .frame(width: 4, height: 4)

            Text(message)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.60))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#0f0f0f"))
        )
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}
