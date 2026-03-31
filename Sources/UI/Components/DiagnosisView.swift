import SwiftUI

// Diagnosis pill — appears when task.rejectionCount >= 3
// Position: drops 40pt LOWER than normal
// Style: warm gray bg, VERTICAL buttons (breaks muscle memory)
struct DiagnosisPillView: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let pillW: CGFloat = 320

    var body: some View {
        ZStack(alignment: .top) {
            // Warm desaturated gray — visually different from normal dark pill
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 60/255, green: 58/255, blue: 55/255).opacity(0.95))

            VStack(alignment: .leading, spacing: 8) {
                Text("You've skipped this 3 times. What's blocking you?")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                // VERTICAL buttons — breaks muscle memory intentionally
                VStack(spacing: 6) {
                    DiagnosisButton(label: "Too big → split into steps") {
                        tooBig()
                    }
                    DiagnosisButton(label: "Wrong time → move to peak energy window") {
                        wrongTime()
                    }
                    DiagnosisButton(label: "Not needed → remove after confirmation",
                                    isDanger: true) {
                        notNeeded()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, notchH - 4)
            .padding(.bottom, 12)
        }
        .frame(width: pillW)
        // Position: 40pt lower than normal pill
        .offset(y: 40)
    }

    private func tooBig() {
        // Show inline text field for first step — handled by parent
        state.showContinuity("Enter the first step in chat")
        state.transition(to: .s4_chat)
    }

    private func wrongTime() {
        guard let task = state.diagnosisTask else { return }
        state.showContinuity("Moved to next peak energy slot")
        EpisodicLog.shared.append(action: "rescheduled", notification: nil, context: state.context, task: task)
        state.diagnosisTask = nil
        state.collapse()
    }

    private func notNeeded() {
        guard let task = state.diagnosisTask else { return }
        state.showContinuity("Removed \(task.title)")
        state.taskQueue.removeAll { $0.id == task.id }
        state.diagnosisTask = nil
        state.collapse()
    }
}

struct DiagnosisButton: View {
    let label: String
    var isDanger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundColor(isDanger ? NT.red : .white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDanger ? NT.red.opacity(0.10) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}
