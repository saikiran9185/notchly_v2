import Foundation

enum DirectorySetup {

    static let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("notchly/v2")

    static let memory    = base.appendingPathComponent("memory")
    static let cache     = base.appendingPathComponent("cache")
    static let logs      = base.appendingPathComponent("logs")

    static let episodicLog      = memory.appendingPathComponent("episodic.jsonl")
    static let semanticProfile  = memory.appendingPathComponent("semantic_profile.json")
    static let workingMemory    = base.appendingPathComponent("working_memory.json")
    static let relationships    = memory.appendingPathComponent("relationships.json")
    static let pendingAlerts    = base.appendingPathComponent("pending_alerts.json")
    static let schedule         = base.appendingPathComponent("schedule.json")
    static let notionCache      = cache.appendingPathComponent("notion_cache.json")
    static let gcalCache        = cache.appendingPathComponent("gcal_cache.json")

    static func createAll() {
        let fm = FileManager.default
        let dirs = [base, memory, cache, logs]
        for dir in dirs {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        // Seed empty files if missing
        let emptyJSON = Data("{}".utf8)
        let emptyJSONL = Data("".utf8)
        let seeds: [(URL, Data)] = [
            (workingMemory,   emptyJSON),
            (semanticProfile, emptyJSON),
            (relationships,   emptyJSON),
            (pendingAlerts,   emptyJSON),
            (schedule,        emptyJSON),
            (notionCache,     emptyJSON),
            (gcalCache,       emptyJSON),
            (episodicLog,     emptyJSONL),
        ]
        for (url, data) in seeds {
            if !fm.fileExists(atPath: url.path) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

// Convenience atomic write extension
extension Data {
    func writeAtomically(to url: URL) throws {
        try write(to: url, options: .atomic)
    }
}
