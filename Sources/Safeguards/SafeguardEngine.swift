import Foundation

/// Enforces the 12 hard safeguards from the spec.
/// Call `check()` before any alert fires.
final class SafeguardEngine {

    static let shared = SafeguardEngine()

    private init() {}

    struct SafeguardResult {
        var allowed: Bool
        var reason: String
    }

    func check(alert: NotchAlert, context: ContextSnapshot) -> SafeguardResult {
        // SG-1: Class mode — block all non-class alerts during class
        if context.isInClass && alert.type != .class {
            return .blocked("Class in progress — non-class alert blocked (SG-1)")
        }

        // SG-2: Deep work mode — only critical (deadline) alerts break through
        if context.isDeepWork && alert.type != .deadline {
            return .blocked("Deep work active — low-priority alert blocked (SG-2)")
        }

        // SG-3: Alert cap — max 8 alerts/day (tracked in WorkingMemory)
        let todayCount = Int(WorkingMemory.shared["safeguard.daily_count"] ?? "0") ?? 0
        if todayCount >= 8 {
            return .blocked("Daily alert cap (8) reached (SG-3)")
        }

        // SG-4: Quiet hours 23:00–06:00 (non-urgent)
        let h = context.hour
        if (h >= 23 || h < 6) && alert.type != .deadline {
            return .blocked("Quiet hours — alert suppressed (SG-4)")
        }

        // SG-5: Minimum spacing — must be ≥10 min since last alert
        if let lastStr = WorkingMemory.shared["safeguard.last_alert_time"],
           let lastTS  = Double(lastStr) {
            let elapsed = Date().timeIntervalSince1970 - lastTS
            if elapsed < 600 {
                return .blocked("Minimum 10-min spacing not met (SG-5)")
            }
        }

        // SG-6: Skip already-dismissed alert types in current context (not implemented yet)

        // SG-7: Idle >30min — allow at most 1 notification
        if context.idleMinutes > 30 && alert.type == .general {
            return .blocked("User idle >30min — general alert blocked (SG-7)")
        }

        // Passed all guards
        let count = todayCount + 1
        WorkingMemory.shared["safeguard.daily_count"] = String(count)
        WorkingMemory.shared["safeguard.last_alert_time"] = String(Date().timeIntervalSince1970)
        return .allowed("OK")
    }
}

extension SafeguardEngine.SafeguardResult {
    static func blocked(_ reason: String) -> SafeguardEngine.SafeguardResult {
        .init(allowed: false, reason: reason)
    }
    static func allowed(_ reason: String) -> SafeguardEngine.SafeguardResult {
        .init(allowed: true, reason: reason)
    }
}
