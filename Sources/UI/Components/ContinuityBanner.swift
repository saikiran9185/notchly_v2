import SwiftUI

// Appears below the pill for 4 seconds after any user action.
// Position: y = notchH + 6pt
// Z-order: below pill, above desktop content
struct ContinuityBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(NT.green)
                .frame(width: 4, height: 4)

            Text(message)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.60))
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
