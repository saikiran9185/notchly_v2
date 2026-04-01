import Foundation

enum DirectorySetup {
    static let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("notchly/v2")

    static let memory   = base.appendingPathComponent("memory")
    static let cache    = base.appendingPathComponent("cache")
    static let logs     = base.appendingPathComponent("logs")

    static let episodicLog      = memory.appendingPathComponent("episodic.jsonl")
    static let semanticProfile  = memory.appendingPathComponent("semantic_profile.json")
    static let workingMemory    = memory.appendingPathComponent("working_memory.json")
    static let relationships    = memory.appendingPathComponent("relationships.json")
    static let pendingAlerts    = base.appendingPathComponent("pending_alerts.json")
    static let schedule         = base.appendingPathComponent("schedule.json")
    static let notionCache      = cache.appendingPathComponent("notion_cache.json")
    static let gcalCache        = cache.appendingPathComponent("gcal_cache.json")
    static let alertsDir        = base.appendingPathComponent("alerts")
    static let alertsProcessed  = base.appendingPathComponent("alerts/processed")
    static let bridgeDir        = base.appendingPathComponent("bridge")
    static let worldState       = base.appendingPathComponent("bridge/world_state_canonical.json")

    static func createAll() {
        let fm = FileManager.default
        let dirs = [base, memory, cache, logs, alertsDir, alertsProcessed, bridgeDir]
        for dir in dirs {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        // Seed empty episodic log if missing
        if !fm.fileExists(atPath: episodicLog.path) {
            fm.createFile(atPath: episodicLog.path, contents: nil)
        }

        // Seed empty pending_alerts.json
        if !fm.fileExists(atPath: pendingAlerts.path) {
            let empty = "[]".data(using: .utf8)
            try? empty?.write(to: pendingAlerts, options: .atomic)
        }

        // Seed empty working_memory.json
        if !fm.fileExists(atPath: workingMemory.path) {
            let seed = WorkingMemoryState()
            if let data = try? JSONEncoder().encode(seed) {
                try? data.write(to: workingMemory, options: .atomic)
            }
        }
    }
}

// Minimal seed struct for working_memory.json
struct WorkingMemoryState: Codable {
    var currentTask: NotchTask? = nil
    var taskQueue: [NotchTask] = []
    var doneToday: [NotchTask] = []
    var interruptionsToday: Int = 0
    var lastInterruptionTS: Date? = nil
    var idleMinutes: Int = 0
    var classMode: Bool = false
    var schedule: [ScheduledBlock] = []
    var missedCount: Int = 0
}

struct ScheduledBlock: Codable {
    var taskID: UUID
    var start: Date
    var end: Date
}
