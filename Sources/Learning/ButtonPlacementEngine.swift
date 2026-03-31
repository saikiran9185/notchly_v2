import Foundation

// Determines left/right button placement based on press history.
// Week 1: fixed defaults. Week 2+: most-pressed action moves to RIGHT.
// right = argmax(press_count[type][context])
// left  = skip/dismiss (always stays left)
class ButtonPlacementEngine {
    static let shared = ButtonPlacementEngine()
    private init() {}

    // Record a button press
    func recordPress(notifType: NotifType, context: ContextSnapshot, action: String) {
        var profile = SemanticProfile.shared.current ?? SemanticProfileData()
        let key = placementKey(notifType: notifType, context: context)
        var map = profile.buttonPlacement[key] ?? [:]
        map[action] = (map[action] ?? 0) + 1
        profile.buttonPlacement[key] = map
        SemanticProfile.shared.update(profile)
    }

    // Get button labels for notification type + context
    func labels(for notifType: NotifType, context: ContextSnapshot) -> NotchNotification {
        var notif = NotchNotification(title: "", type: notifType)
        let defaults = notifType.defaultButtons
        notif.leftAction   = defaults.left
        notif.centerAction = defaults.center
        notif.rightAction  = defaults.right

        // Week 2+: check press history
        guard let profile = SemanticProfile.shared.current,
              profile.totalDataPoints >= 50  // at least 1 week of data
        else { return notif }

        let key = placementKey(notifType: notifType, context: context)
        guard let pressMap = profile.buttonPlacement[key],
              let topAction = pressMap.max(by: { $0.value < $1.value })?.key,
              topAction != defaults.left   // skip/dismiss stays left
        else { return notif }

        notif.rightAction = topAction
        // Hint text updates automatically from button labels
        return notif
    }

    private func placementKey(notifType: NotifType, context: ContextSnapshot) -> String {
        let day = Calendar.current.component(.weekday, from: Date())
        let isWeekend = day == 1 || day == 7
        return "\(notifType.rawValue)_\(isWeekend ? "weekend" : "weekday")"
    }
}
