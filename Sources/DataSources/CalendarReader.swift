import Foundation
import EventKit

// ONE EKEventStore — CalendarReader.shared. No exceptions.
// V2 Rule: Single singleton. EventKit undefined with multiple stores.
class CalendarReader {
    static let shared = CalendarReader()

    private let store = EKEventStore()
    private var granted: Bool = false

    private init() {}

    // MARK: - Permission
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] g, _ in
                DispatchQueue.main.async {
                    self?.granted = g
                    completion(g)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] g, _ in
                DispatchQueue.main.async {
                    self?.granted = g
                    completion(g)
                }
            }
        }
    }

    // MARK: - 4 Calendars
    // 1. Primary: saikiran9185@gmail.com
    // 2. Hostel Mess calendar
    // 3. Google Tasks calendar
    // 4. USDI B.Des class calendar
    private let classCalendarID = ProcessInfo.processInfo.environment["CLASS_CALENDAR_ID"] ?? ""

    func loadTodayEvents() -> [EKEvent] {
        guard granted else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred)
    }

    func loadEvents(from start: Date, to end: Date) -> [EKEvent] {
        guard granted else { return [] }
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred)
    }

    // MARK: - Class detection
    // Event is a class if any of:
    // 1. Calendar ID matches USDI
    // 2. Title contains: lecture, class, lab, studio, tutorial, workshop, crit, seminar
    // 3. Location contains: USDI, IP University, university, college, campus
    func isClass(_ event: EKEvent) -> Bool {
        if event.calendar?.calendarIdentifier == classCalendarID { return true }

        let classKeywords = ["lecture", "class", "lab", "studio", "tutorial",
                             "workshop", "crit", "seminar"]
        let locationKeywords = ["usdi", "ip university", "university", "college", "campus"]

        let title = (event.title ?? "").lowercased()
        let location = (event.location ?? "").lowercased()

        if classKeywords.contains(where: { title.contains($0) }) { return true }
        if locationKeywords.contains(where: { location.contains($0) }) { return true }
        return false
    }

    // MARK: - Mess detection
    // Event is a mess (hostel cafeteria) if title/notes contain mess-related keywords.
    func isMess(_ event: EKEvent) -> Bool {
        let messKeywords = ["mess", "breakfast", "lunch", "dinner", "cafeteria", "canteen", "dining"]
        let title = (event.title ?? "").lowercased()
        let notes = (event.notes ?? "").lowercased()
        return messKeywords.contains(where: { title.contains($0) || notes.contains($0) })
    }

    func isCurrentlyInClass() -> Bool {
        let now = Date()
        return loadTodayEvents().contains { event in
            isClass(event) &&
            event.startDate <= now &&
            event.endDate >= now
        }
    }

    // MARK: - Free blocks (gaps between events today)
    func todayFreeBlocks() -> [(start: Date, end: Date)] {
        let events = loadTodayEvents().sorted { $0.startDate < $1.startDate }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: Date())
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var blocks: [(start: Date, end: Date)] = []
        var cursor = Date()  // now

        for event in events {
            if event.startDate > cursor {
                let gap = event.startDate.timeIntervalSince(cursor)
                if gap >= 900 { // min 15min block
                    blocks.append((start: cursor, end: event.startDate))
                }
            }
            cursor = max(cursor, event.endDate)
        }
        if cursor < dayEnd {
            blocks.append((start: cursor, end: dayEnd))
        }
        return blocks
    }
}
