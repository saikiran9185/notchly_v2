import Foundation

// SAFEGUARD 1 — Task Purgatory (diagnosis mode)
// Trigger: task.rejectionCount >= 3
// Appearance: pill drops 40pt lower, warm gray bg, VERTICAL buttons
// Handles: too big / wrong time / not needed
class DiagnosisMode {
    static let shared = DiagnosisMode()
    private init() {}

    func check(task: inout NotchTask, state: NotchState) {
        guard task.rejectionCount >= 3 else { return }
        triggerDiagnosis(for: task, state: state)
    }

    private func triggerDiagnosis(for task: NotchTask, state: NotchState) {
        state.diagnosisTask = task
        state.transition(to: .s1_5x_diagnosis, spring: Springs.pill)
        // DiagnosisPillView handles the UI (gray + vertical buttons)
    }

    // "Too big" action: split into steps — opens S4 with prompt
    func handleTooBig(task: NotchTask, state: NotchState) {
        state.diagnosisTask = nil
        state.showContinuity("Tell me the first step in chat")
        state.transition(to: .s4_chat)
        EpisodicLog.shared.append(action: "diagnosis_split", notification: nil,
                                  context: state.context, task: task)
    }

    // "Wrong time" action: reschedule to next peak energy slot
    func handleWrongTime(task: NotchTask, state: NotchState) {
        var t = task
        t.rejectionCount = 0
        // Find next E≥8 slot and reschedule
        let cal = Calendar.current
        let now = Date()
        let currentHour = cal.component(.hour, from: now) + 1
        var found = false
        for h in currentHour...23 {
            if EnergyModel.shared.isPeakSlot(at: h) {
                var comps = cal.dateComponents([.year, .month, .day], from: now)
                comps.hour = h
                comps.minute = 0
                t.scheduledStart = cal.date(from: comps)
                found = true
                break
            }
        }
        if !found {
            // BUG-22 fix: was `var t2 = task` (local, never saved). Now update `t` directly.
            t.scheduledStart = cal.date(byAdding: .day, value: 1, to: now)
        }
        // Write updated task back to queue
        if let idx = state.taskQueue.firstIndex(where: { $0.id == t.id }) {
            state.taskQueue[idx] = t
        }
        state.diagnosisTask = nil
        state.showContinuity("Moved to next peak energy window")
        state.collapse()
        EpisodicLog.shared.append(action: "diagnosis_reschedule", notification: nil,
                                  context: state.context, task: t)
    }

    // "Not needed" action: remove task after confirmation
    func handleNotNeeded(task: NotchTask, state: NotchState) {
        state.taskQueue.removeAll { $0.id == task.id }
        state.diagnosisTask = nil
        state.showContinuity("Removed \(task.title)")
        state.collapse()
        EpisodicLog.shared.append(action: "diagnosis_removed", notification: nil,
                                  context: state.context, task: task)
        WorkingMemory.shared.save(state: state)
    }
}
