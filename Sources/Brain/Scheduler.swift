import Foundation
import EventKit

// Dynamic rescheduler — called after EVERY user action.
// AI never asks "when?". AI proposes specific times.
class Scheduler {
    static let shared = Scheduler()
    private init() {}

    // Called after: done/skip/postpone/extend/swipe
    func rescheduleAll(tasks: inout [NotchTask], context: ContextSnapshot) {
        // 1. Score all incomplete tasks
        tasks = PriorityScorer.shared.scoreAll(
            tasks.filter { !$0.isCompleted }, context: context)

        // 2. Filter blocked (C=0 = wrong context)
        let available = tasks.filter { $0.contextFit > 0 }

        // 3. Tasks already sorted by P score from scorer
        // 4. Get today's free blocks
        let freeBlocks = CalendarReader.shared.todayFreeBlocks()

        // 5. Match tasks to slots
        var schedule: [ScheduledBlock] = []
        var usedTime = Date()

        for block in freeBlocks {
            let energy = EnergyModel.shared.currentEnergy(
                at: Calendar.current.component(.hour, from: block.start))
            let isPeak = energy >= 8
            let isDip  = energy <= 5

            // Pick appropriate task category for slot
            let candidates = available.filter { task in
                if isPeak { return [.deepWork, .creative, .study].contains(task.category) }
                if isDip  { return [.admin, .review].contains(task.category) }
                return true
            }

            for task in candidates {
                let duration = TimeInterval(task.estimatedMinutes * 60)
                let slotAvail = block.end.timeIntervalSince(block.start)
                guard slotAvail >= duration else { continue }

                let start = max(block.start, usedTime + 600) // 10min context switch
                let end   = start.addingTimeInterval(duration)
                guard end <= block.end else { continue }

                schedule.append(ScheduledBlock(taskID: task.id, start: start, end: end))
                usedTime = end
                break
            }
        }

        // 6. Apply transit buffer: 15min after class, 20min before first task
        applyBuffers(&schedule)

        // 9. Write schedule atomically
        if let data = try? JSONEncoder().encode(schedule) {
            try? data.write(to: DirectorySetup.schedule, options: .atomic)
        }
    }

    private func applyBuffers(_ schedule: inout [ScheduledBlock]) {
        // Simplified — full buffer logic in Phase G Python scheduler
        // Just ensure 10min gaps between tasks
        for i in 1..<schedule.count {
            let prev = schedule[i-1]
            if schedule[i].start < prev.end + 600 {
                let gap = prev.end + 600
                let duration = schedule[i].end.timeIntervalSince(schedule[i].start)
                schedule[i].start = gap
                schedule[i].end   = gap + duration
            }
        }
    }

    // Auto-reschedule after 3× postpone
    func autoRescheduleTomorrow(_ task: inout NotchTask) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour   = 10
        comps.minute = 0
        task.scheduledStart = Calendar.current.date(from: comps)
        task.postponeCount  = 0
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Rust Pulse Bridge (WorldState reader)
// Reads ~/notchly/v2/bridge/world_state_canonical.json written by notchly_pulse
// ─────────────────────────────────────────────────────────────────────────────

struct WorldState: Decodable {
    let pulseVersion: String
    let generatedAt: Double
    let aiStatus: String
    let taskQueue: [PulseTask]
    let currentTask: PulseTask?
    let nextTask: PulseTask?
    let missedCount: Int

    enum CodingKeys: String, CodingKey {
        case pulseVersion = "pulse_version"
        case generatedAt  = "generated_at"
        case aiStatus     = "ai_status"
        case taskQueue    = "task_queue"
        case currentTask  = "current_task"
        case nextTask     = "next_task"
        case missedCount  = "missed_count"
    }
}

struct PulseTask: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let taskType: String
    let durationMinutes: Int
    let progressPct: Double
    let priority: Double
    let appBundle: String?
    let isDone: Bool
    let isSkipped: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, priority
        case taskType        = "type"
        case durationMinutes = "duration_minutes"
        case progressPct     = "progress_pct"
        case appBundle       = "app_bundle"
        case isDone          = "is_done"
        case isSkipped       = "is_skipped"
    }

    func toNotchTask() -> NotchTask {
        let cat: TaskCategory = {
            switch taskType {
            case "meal":      return .meal
            case "class":     return .class
            case "exercise":  return .exercise
            case "break":     return .break
            case "deep_work": return .deepWork
            case "study":     return .study
            default:          return .other
            }
        }()
        var t = NotchTask(title: title)
        t.subtitle           = subtitle ?? ""
        t.category           = cat
        t.estimatedMinutes   = durationMinutes
        t.progressPercent    = progressPct
        t.pFinal             = priority
        t.relatedAppBundleID = appBundle
        t.isCompleted        = isDone
        return t
    }
}

final class WorldStateReader {
    static let shared = WorldStateReader()

    private let stateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("notchly/v2/bridge/world_state_canonical.json")
    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var lastTS: Double = 0

    private init() {}

    func start() {
        ensureDirs()
        startFileSource()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    func stop() {
        source?.cancel()
        pollTimer?.invalidate()
    }

    private func ensureDirs() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("notchly/v2")
        for d in ["bridge", "alerts", "alerts/processed", "queue", "memory"] {
            try? FileManager.default.createDirectory(
                at: base.appendingPathComponent(d),
                withIntermediateDirectories: true)
        }
    }

    private func startFileSource() {
        let dir = stateURL.deletingLastPathComponent()
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .global(qos: .utility)
        )
        source?.setEventHandler { [weak self] in self?.reload() }
        source?.setCancelHandler { close(fd) }
        source?.resume()
    }

    private func reload() {
        guard let data = try? Data(contentsOf: stateURL),
              let world = try? JSONDecoder().decode(WorldState.self, from: data),
              world.generatedAt > lastTS else { return }
        lastTS = world.generatedAt
        DispatchQueue.main.async {
            NotchState.shared.applyWorldState(world)
        }
    }
}
