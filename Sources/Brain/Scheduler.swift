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
