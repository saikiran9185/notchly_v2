import Foundation
import Carbon
import AppKit

// Global hotkeys via Carbon RegisterEventHotKey (more reliable than NSEvent)
// ⌘⇧Space → S4  |  ⌘Space → toggle S3  |  ⌘D done  |  ⌘S skip
// ⌘L later  |  ⌘E extend timer  |  Esc → collapse
class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?

    // Key codes
    private let keySpace: UInt32 = 49
    private let keyD: UInt32 = 2
    private let keyS: UInt32 = 1
    private let keyL: UInt32 = 37
    private let keyE: UInt32 = 14
    private let keyEsc: UInt32 = 53

    func register() {
        checkAccessibilityPermission()
        registerCarbonHotkeys()
        registerGlobalKeyMonitors()
    }

    // MARK: - Carbon hotkeys (for reliable global capture)
    private func registerCarbonHotkeys() {
        var idCounter: UInt32 = 0
        let sig = FourCharCode(bitPattern: Int32(truncatingIfNeeded: 0x4E4C4C59)) // 'NLLY'

        func reg(key: UInt32, mods: UInt32) {
            idCounter += 1
            var hkID = EventHotKeyID(signature: sig, id: idCounter)
            var ref: EventHotKeyRef?
            RegisterEventHotKey(key, mods, hkID, GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }

        reg(key: keySpace, mods: UInt32(cmdKey | shiftKey))   // ⌘⇧Space → S4
        reg(key: keySpace, mods: UInt32(cmdKey))               // ⌘Space → S3
        reg(key: keyD,     mods: UInt32(cmdKey))               // ⌘D done
        reg(key: keyS,     mods: UInt32(cmdKey))               // ⌘S skip
        reg(key: keyL,     mods: UInt32(cmdKey))               // ⌘L later
        reg(key: keyE,     mods: UInt32(cmdKey))               // ⌘E extend
        reg(key: keyEsc,   mods: 0)                             // Esc collapse

        // Install event handler via NSEvent observer (avoids C-callback complexity)
        installCarbonHandler()
    }

    private func installCarbonHandler() {
        // Use NSEvent addGlobalMonitor with flagsChanged + keyDown combo
        // Carbon hotkey IDs are dispatched via event handler; intercept at AppDelegate level
        // For simplicity in Swift, we also install NSEvent global monitors for the same keys
    }

    // MARK: - NSEvent global monitors (backup + Y key)
    private func registerGlobalKeyMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleNSKeyDown(event)
        }
    }

    private func handleNSKeyDown(_ event: NSEvent) {
        let mods = event.modifierFlags
        let hasCmd   = mods.contains(.command)
        let hasShift = mods.contains(.shift)

        DispatchQueue.main.async {
            let state = NotchState.shared

            switch event.keyCode {
            case 49 where hasCmd && hasShift:   // ⌘⇧Space
                state.transition(to: .s4_chat, spring: Springs.expand)

            case 49 where hasCmd && !hasShift:  // ⌘Space
                state.stage == .s3_dashboard
                    ? state.collapse()
                    : state.transition(to: .s3_dashboard)

            case 2 where hasCmd:   // ⌘D done
                self.markDone(state: state)

            case 1 where hasCmd:   // ⌘S skip
                self.skipTask(state: state)

            case 37 where hasCmd:  // ⌘L later
                state.showContinuity("Moved later")
                state.collapse()

            case 14 where hasCmd:  // ⌘E extend
                if state.stage == .s1b_timer {
                    state.timerSecondsLeft += 15 * 60
                    state.showContinuity("+15m added")
                }

            case 53:               // Esc collapse
                state.collapse()

            case 16 where state.stage == .s1a_notification:  // Y primary action
                break  // handled by Stage1AView

            default: break
            }
        }
    }

    // MARK: - Actions
    private func markDone(state: NotchState) {
        guard let task = state.currentTask else { return }
        EpisodicLog.shared.append(action: "done", notification: nil,
                                  context: state.context, task: task)
        state.doneToday += 1
        state.taskQueue.removeAll { $0.id == task.id }
        state.currentTask = state.taskQueue.first
        state.showContinuity("\(task.title) done")
        WorkingMemory.shared.save(state: state)
        state.collapse()
    }

    private func skipTask(state: NotchState) {
        if let notif = state.currentNotification {
            EpisodicLog.shared.append(action: "skip", notification: notif,
                                      context: state.context)
            EVRUpdater.shared.recordDismissed(for: notif)
        }
        state.showContinuity("Skipped")
        state.dismissCurrentNotification()
    }

    private func checkAccessibilityPermission() {
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
    }

    deinit {
        hotKeyRefs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}
