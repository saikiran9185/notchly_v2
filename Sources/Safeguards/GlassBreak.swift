import Foundation
import AppKit

// SAFEGUARD 2 — Glass Break (emergency override)
// Trigger: user holds Option key while burnout/boundary alert visible
// Action: disables all wellness sensors until midnight
// Appearance: completely invisible in normal use. Only shows with Option held.
class GlassBreak {
    static let shared = GlassBreak()
    private init() {}

    private(set) var isActive: Bool = false
    private var resetTimer: Timer?

    func activate() {
        isActive = true
        scheduleReset()
    }

    func deactivate() {
        isActive = false
        resetTimer?.invalidate()
    }

    private func scheduleReset() {
        resetTimer?.invalidate()
        let cal = Calendar.current
        let now = Date()
        guard let midnight = cal.nextDate(after: now,
                                          matching: DateComponents(hour: 0, minute: 0),
                                          matchingPolicy: .nextTime)
        else { return }
        let delay = midnight.timeIntervalSince(now)
        resetTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.isActive = false
        }
    }

    // Check if Option key is currently held
    static var optionKeyHeld: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    deinit { resetTimer?.invalidate() }
}
