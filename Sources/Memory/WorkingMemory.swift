import Foundation

// Working memory — resets at midnight. Swift reads AND writes.
// Python reads this to know current task queue.
class WorkingMemory {
    static let shared = WorkingMemory()
    private init() {}

    private let url = DirectorySetup.workingMemory
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(state: NotchState) {
        let mem = WorkingMemoryState(
            currentTask: state.currentTask,
            taskQueue: state.taskQueue,
            doneToday: [],
            interruptionsToday: 0,
            lastInterruptionTS: nil,
            idleMinutes: state.context.idleMinutes,
            classMode: state.isClassMode,
            schedule: [],
            missedCount: state.missedNotifications.count
        )
        if let data = try? encoder.encode(mem) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load() -> WorkingMemoryState? {
        guard let data = try? Data(contentsOf: url),
              let mem = try? decoder.decode(WorkingMemoryState.self, from: data)
        else { return nil }
        return mem
    }

    // Tomorrow's schedule preview for S4 context peek
    func tomorrowPreview() -> [ContextPeekEvent] {
        // Reads gcal_cache.json for tomorrow's events
        guard let data = try? Data(contentsOf: DirectorySetup.gcalCache),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["tomorrow"] as? [[String: String]]
        else {
            return [
                ContextPeekEvent(time: "09:00", title: "Class – Studio Design", duration: "2h",   colorHex: "#4A90E2"),
                ContextPeekEvent(time: "12:30", title: "Lunch",                  duration: "45m", colorHex: "#BA7517"),
                ContextPeekEvent(time: "14:00", title: "Free block",             duration: "3h",  colorHex: "#5F5E5A")
            ]
        }
        return events.prefix(3).map {
            ContextPeekEvent(
                time:     $0["time"] ?? "",
                title:    $0["title"] ?? "",
                duration: $0["duration"] ?? "",
                colorHex: $0["color"] ?? "#5F5E5A"
            )
        }
    }

    // BUG-16 fix: guard against multiple simultaneous schedulings
    private var midnightScheduled = false

    func scheduleMidnightReset() {
        guard !midnightScheduled else { return }
        midnightScheduled = true

        let now = Date()
        let cal = Calendar.current
        guard let midnight = cal.nextDate(after: now,
                                          matching: DateComponents(hour: 0, minute: 0),
                                          matchingPolicy: .nextTime)
        else { midnightScheduled = false; return }

        let delay = midnight.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.midnightScheduled = false   // allow next scheduling
            self.midnightReset()
            self.scheduleMidnightReset()     // reschedule for next midnight
        }
    }

    private func midnightReset() {
        let fresh = WorkingMemoryState()
        if let data = try? encoder.encode(fresh) {
            try? data.write(to: url, options: .atomic)
        }
        DispatchQueue.main.async {
            NotchState.shared.doneToday = 0
        }
    }
}
