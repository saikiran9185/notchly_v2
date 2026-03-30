import Foundation

enum EpisodicEvent {
    case alertAccepted(alertID: String)
    case alertDismissed(alertID: String)
    case taskCompleted(taskID: String)
    case taskPostponed(taskID: String)
    case stageSwitched(from: String, to: String)
    case chatMessage(role: String, text: String)
    case custom(key: String, value: String)
}

struct EpisodicEntry: Codable {
    let timestamp: TimeInterval
    let eventType: String
    let payload: [String: String]
}

/// Append-only .jsonl log — each line is a JSON-encoded EpisodicEntry.
final class EpisodicLog {

    static let shared = EpisodicLog()
    private let logURL = DirectorySetup.episodicLog
    private let queue = DispatchQueue(label: "com.notchly.episodiclog", qos: .background)
    private let maxLines = 10_000

    private init() {}

    func log(event: EpisodicEvent) {
        let entry = EpisodicEntry(
            timestamp: Date().timeIntervalSince1970,
            eventType: eventType(event),
            payload:   payload(event)
        )
        queue.async { [weak self] in
            guard let self = self,
                  let data = try? JSONEncoder().encode(entry),
                  let line = String(data: data, encoding: .utf8) else { return }
            self.append(line: line)
        }
    }

    // MARK: - Private

    private func append(line: String) {
        let existing = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.append(line)
        // Trim old entries if over limit
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
        }
        try? (lines.joined(separator: "\n") + "\n").write(to: logURL, atomically: true, encoding: .utf8)
    }

    private func eventType(_ event: EpisodicEvent) -> String {
        switch event {
        case .alertAccepted:  return "alert.accepted"
        case .alertDismissed: return "alert.dismissed"
        case .taskCompleted:  return "task.completed"
        case .taskPostponed:  return "task.postponed"
        case .stageSwitched:  return "stage.switched"
        case .chatMessage:    return "chat.message"
        case .custom:         return "custom"
        }
    }

    private func payload(_ event: EpisodicEvent) -> [String: String] {
        switch event {
        case .alertAccepted(let id):          return ["alertID": id]
        case .alertDismissed(let id):         return ["alertID": id]
        case .taskCompleted(let id):          return ["taskID": id]
        case .taskPostponed(let id):          return ["taskID": id]
        case .stageSwitched(let f, let t):    return ["from": f, "to": t]
        case .chatMessage(let r, let text):   return ["role": r, "text": text]
        case .custom(let k, let v):           return [k: v]
        }
    }
}
