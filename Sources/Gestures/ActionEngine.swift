import Foundation

/// Routes user actions (accept / dismiss / snooze) from SwipeHandler and button taps.
final class ActionEngine {

    static let shared = ActionEngine()
    private init() {}

    // MARK: - Alert actions

    func acceptCurrentAlert() {
        guard let alert = NotchState.shared.currentAlert else { return }
        LearningEngine.shared.recordAccept(alert: alert)
        EpisodicLog.shared.log(event: .alertAccepted(alertID: alert.id.uuidString))
        NotchState.shared.showBanner("Done — \(alert.title)")
        clearCurrentAlert()
    }

    func dismissCurrentAlert() {
        guard let alert = NotchState.shared.currentAlert else { return }
        LearningEngine.shared.recordDismiss(alert: alert)
        NotchState.shared.addMissed(alert)
        EpisodicLog.shared.log(event: .alertDismissed(alertID: alert.id.uuidString))
        clearCurrentAlert()
    }

    func snoozeCurrentAlert(minutes: Int) {
        guard let alert = NotchState.shared.currentAlert else { return }
        // Re-queue alert after `minutes`
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes * 60)) { [weak self] in
            AlertScheduler.shared.fire(alert)
        }
        NotchState.shared.showBanner("Snoozed \(minutes)m — \(alert.title)")
        clearCurrentAlert()
    }

    func taskCompleted(task: NotchTask) {
        LearningEngine.shared.recordTaskDone(task: task)
        EpisodicLog.shared.log(event: .taskCompleted(taskID: task.id.uuidString))
        NotchState.shared.showBanner("\(task.title) complete!")
        dequeueTask(task)
    }

    func postponeTask(_ task: NotchTask) {
        var t = task
        t.postponeCount += 1
        LearningEngine.shared.recordPostpone(task: t)
        dequeueTask(task)
        NotchState.shared.showBanner("Postponed — \(task.title)")
    }

    // MARK: - Private helpers

    private func clearCurrentAlert() {
        NotchState.shared.currentAlert = nil
        NotchState.shared.collapseToIdle()
    }

    private func dequeueTask(_ task: NotchTask) {
        NotchState.shared.taskQueue.removeAll { $0.id == task.id }
        NotchState.shared.currentTask = NotchState.shared.taskQueue.first
        NotchState.shared.collapseToIdle()
    }
}
