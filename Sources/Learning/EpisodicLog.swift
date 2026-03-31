import Foundation

// Append-only episodic log — NEVER full read+rewrite.
// Uses FileHandle O_APPEND for every write.
class EpisodicLog {
    static let shared = EpisodicLog()
    private init() {}

    private let url = DirectorySetup.episodicLog
    private let encoder = JSONEncoder()

    // Convenience overloads
    func append(action: String,
                notification: NotchNotification?,
                context: ContextSnapshot,
                task: NotchTask? = nil) {
        let entry = EpisodicEntry(
            ts: ISO8601DateFormatter().string(from: Date()),
            action: action,
            notifType: notification?.type.rawValue ?? task?.category.rawValue ?? "unknown",
            taskTitle: notification?.title ?? task?.title ?? "",
            context: EpisodicContext(
                hour: context.hour,
                dayOfWeek: Calendar.current.component(.weekday, from: Date()),
                hasClass: context.isInClass,
                deadlineToday: context.maxDeadlinePressure > 5,
                energy: context.energyLevel,
                frontmost: context.frontmostApp
            ),
            responseDelayS: 0,
            evrAtFire: notification?.evrAtFire ?? 0,
            wBefore: notification?.wWeight ?? 0,
            wAfter: notification?.wWeight ?? 0,
            buttonSide: action
        )
        appendEntry(entry)
    }

    private func appendEntry(_ entry: EpisodicEntry) {
        guard let data = try? encoder.encode(entry),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        guard let lineData = line.data(using: .utf8) else { return }

        // O_APPEND atomic write via FileHandle
        do {
            let fh = try FileHandle(forWritingTo: url)
            defer { try? fh.close() }
            try fh.seekToEnd()
            try fh.write(contentsOf: lineData)
        } catch {
            // If file missing, try creating and retrying once
            FileManager.default.createFile(atPath: url.path, contents: nil)
            if let fh = try? FileHandle(forWritingTo: url) {
                try? fh.seekToEnd()
                try? fh.write(contentsOf: lineData)
                try? fh.close()
            }
        }
    }

    // Count total data points (for CAP β calculation)
    func totalDataPoints() -> Int {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }
}

struct EpisodicEntry: Codable {
    var ts: String
    var action: String
    var notifType: String
    var taskTitle: String
    var context: EpisodicContext
    var responseDelayS: Double
    var evrAtFire: Double
    var wBefore: Double
    var wAfter: Double
    var buttonSide: String

    enum CodingKeys: String, CodingKey {
        case ts, action
        case notifType  = "notif_type"
        case taskTitle  = "task_title"
        case context
        case responseDelayS   = "response_delay_s"
        case evrAtFire        = "evr_at_fire"
        case wBefore          = "W_before"
        case wAfter           = "W_after"
        case buttonSide       = "button_side"
    }
}

struct EpisodicContext: Codable {
    var hour: Int
    var dayOfWeek: Int
    var hasClass: Bool
    var deadlineToday: Bool
    var energy: Double
    var frontmost: String

    enum CodingKeys: String, CodingKey {
        case hour
        case dayOfWeek     = "day_of_week"
        case hasClass      = "has_class"
        case deadlineToday = "deadline_today"
        case energy, frontmost
    }
}
