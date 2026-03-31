import SwiftUI

// Context Peek — appears inside Stage 4 when schedule keywords are typed.
// Height: 0→60pt spring on keyword detection. Zero API call (client-side string match).
struct ContextPeekView: View {
    let events: [ContextPeekEvent]   // max 3 items

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOMORROW — CONTEXT PEEK")
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(NT.purple.opacity(0.40))

            ForEach(events.prefix(3)) { event in
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: event.colorHex))
                        .frame(width: 3, height: 3)

                    Text("\(event.time) · \(event.title)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.25))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(event.duration)
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5))
        )
    }

    // Schedule keywords that trigger peek
    static let triggerKeywords = ["move", "tomorrow", "reschedule", "when", "free",
                                  "deadline", "today", "later", "morning", "evening",
                                  "after", "before", "time"]

    static func shouldShow(for text: String) -> Bool {
        let lower = text.lowercased()
        return triggerKeywords.contains { lower.contains($0) }
    }
}

struct ContextPeekEvent: Identifiable {
    var id: UUID = UUID()
    var time: String
    var title: String
    var duration: String
    var colorHex: String = "#5F5E5A"
}
