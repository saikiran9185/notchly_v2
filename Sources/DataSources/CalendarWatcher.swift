import Foundation
import EventKit

/// Watches EKEventStore and publishes upcoming events.
final class CalendarWatcher {

    static let shared = CalendarWatcher()
    private let store = EKEventStore()
    private var timer: Timer?

    var onEventChange: (([EKEvent]) -> Void)?

    private init() {}

    func start() {
        requestAccessIfNeeded { [weak self] granted in
            guard granted else { return }
            self?.schedulePoll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func fetchToday() -> [EKEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    func fetchNext(hours: Int = 3) -> EKEvent? {
        let now  = Date()
        let end  = Date(timeIntervalSinceNow: Double(hours * 3600))
        let pred = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        return store.events(matching: pred).min { $0.startDate < $1.startDate }
    }

    // MARK: - Private

    private func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    private func schedulePoll() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let events = self.fetchToday()
            self.onEventChange?(events)
        }
        timer?.fire()
    }
}
