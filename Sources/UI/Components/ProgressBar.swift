import SwiftUI

// 2pt height progress bar with color based on completion %
struct ProgressBar: View {
    let progress: Double   // 0.0–1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 2)
    }

    private var barColor: Color {
        switch progress {
        case 0.6...1.0: return NT.green
        case 0.2..<0.6: return NT.amber
        default:        return NT.red
        }
    }
}

// Mini version for S3 task rows (3pt height, 48pt wide)
struct MiniProgressBar: View {
    let progress: Double

    var body: some View {
        ProgressBar(progress: progress)
            .frame(width: 48, height: 3)
    }
}
