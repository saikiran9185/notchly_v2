import Foundation

/// Reads pending_alerts.json and fires alerts into NotchState at the right time.
final class AlertScheduler {

    static let shared = AlertScheduler()
    private var timer: Timer?
    private let url = DirectorySetup.pendingAlerts

    private init() {}

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkDue()
        }
        timer?.fire()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func fire(_ alert: NotchAlert) {
        DispatchQueue.main.async {
            let state = NotchState.shared
            state.currentAlert = alert
            state.transition(to: .s1a_notification)
        }
    }

    func scheduleAlert(_ alert: NotchAlert, at date: Date) {
        var alerts = loadAlerts()
        alerts.append(ScheduledAlert(alert: alert, fireAt: date))
        saveAlerts(alerts)
    }

    // MARK: - Private

    private func checkDue() {
        var alerts = loadAlerts()
        let now = Date()
        let due = alerts.filter { $0.fireAt <= now }
        alerts.removeAll { $0.fireAt <= now }
        saveAlerts(alerts)

        for scheduled in due {
            fire(scheduled.alert)
        }
    }

    private func loadAlerts() -> [ScheduledAlert] {
        guard let data = try? Data(contentsOf: url),
              let alerts = try? JSONDecoder().decode([ScheduledAlert].self, from: data) else { return [] }
        return alerts
    }

    private func saveAlerts(_ alerts: [ScheduledAlert]) {
        guard let data = try? JSONEncoder().encode(alerts) else { return }
        try? data.writeAtomically(to: url)
    }
}

private struct ScheduledAlert: Codable {
    var alert: NotchAlert
    var fireAt: Date
}
