import AppKit

/// Monitors global left-mouse-up events for double-clicks in the notch zone.
///
/// Spec rule: when S1a/S1b active → fire primary action (S1 owns notch).
///            all other stages   → open S4 chat.
final class DoubleClickHandler {

    static let shared = DoubleClickHandler()
    private var globalMonitor: Any?

    private init() {}

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.clickCount == 2,
              HoverZoneMonitor.shared.cursorInNotchZone() else { return }

        DispatchQueue.main.async {
            let stage = NotchState.shared.stage
            switch stage {
            case .s1a_notification, .s1b_timer:
                // S1 owns the notch — double-click fires primary action, NOT S4
                ActionEngine.shared.acceptCurrentAlert()
            default:
                HotKeyManager.openS4()
            }
        }
    }
}
