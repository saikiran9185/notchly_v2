import Foundation
import Carbon
import AppKit
import SwiftUI

// Keyboard handling for Notchly v2
// ─────────────────────────────────────────────────────────────────────────────
// RULE: only ⌘⇧Space is a Carbon global hotkey (unique, intentional, no conflicts).
//
// Everything else uses a LOCAL NSEvent monitor — it fires ONLY when our panel
// is the key window. This means ⌘E, ⌘D, ⌘S, ⌘L are NEVER stolen from
// Xcode, browsers, Terminal or any other app.
//
// Esc passes through to macOS when stage == .s0_idle (notch is hidden).
// ─────────────────────────────────────────────────────────────────────────────
class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var carbonChatRef: EventHotKeyRef?
    private var globalChatMonitor: Any?   // observes ⌘⇧Space only (no swallow, can't steal)
    private var localMonitor: Any?

    func register() {
        checkAccessibilityPermission()
        registerCarbonChatShortcut()
        registerGlobalChatMonitor()
        registerLocalMonitor()
    }

    // MARK: - Global observer: ⌘⇧Space from any app
    // NSEvent global monitors CANNOT swallow events — they only observe.
    // ⌘⇧Space has no macOS system use, so this is safe.
    private func registerGlobalChatMonitor() {
        globalChatMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == UInt16(kVK_Space),
                  mods == [.command, .shift] else { return }
            DispatchQueue.main.async {
                if !AXIsProcessTrusted() { self?.checkAccessibilityPermission(); return }
                let state = NotchState.shared
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    state.rawProgress     = 1.0
                    state.displayProgress = 1.0
                    state.scrollProgress  = 1.0
                }
                state.transition(to: .s4_chat, spring: Springs.expand)
            }
        }
    }

    // MARK: - Carbon: ⌘⇧Space only
    // Only one Carbon hotkey: ⌘⇧Space → open Stage 4 chat from any app.
    // ⌘Space is intentionally NOT registered (Spotlight owns it).
    // ⌘D/S/L/E are intentionally NOT registered (common editing shortcuts).
    private func registerCarbonChatShortcut() {
        // BUG-4 fix: check return value — only store ref on success
        let sig = FourCharCode(bitPattern: Int32(truncatingIfNeeded: 0x4E4C4C59)) // 'NLLY'
        let hkID = EventHotKeyID(signature: sig, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr { carbonChatRef = ref }
    }

    // MARK: - Local monitor (panel must be key window)
    private func registerLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            return self?.handleLocalKey(event) ?? event
        }
    }

    /// Returns nil to consume the event, or the original event to pass it through.
    private func handleLocalKey(_ event: NSEvent) -> NSEvent? {
        let mods     = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd   = mods.contains(.command)
        let hasShift = mods.contains(.shift)
        let state    = NotchState.shared

        switch event.keyCode {

        // ── Esc ─────────────────────────────────────────────────────────────
        case 53:
            if state.stage == .s0_idle {
                return event   // pass through: don't intercept Esc when notch is hidden
            }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    state.scrollProgress = 0
                }
                state.collapse()
            }
            return nil   // consume: collapse the notch

        // ── ⌘⇧Space → Stage 4 chat ─────────────────────────────────────────
        // Also handled by Carbon for background access, but local swallows it
        // when the panel is already key so we don't double-fire.
        case UInt16(kVK_Space) where hasCmd && hasShift:
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    state.rawProgress     = 1.0
                    state.displayProgress = 1.0
                    state.scrollProgress  = 1.0
                }
                state.transition(to: .s4_chat, spring: Springs.expand)
            }
            return nil

        // ── ⌘Space → toggle Stage 3 (local only — Spotlight when notch idle) ─
        case UInt16(kVK_Space) where hasCmd && !hasShift:
            // Only intercept when notch is already expanded; pass to Spotlight otherwise
            guard state.stage != .s0_idle else { return event }
            DispatchQueue.main.async {
                if state.stage == .s3_dashboard {
                    state.collapse()
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        state.rawProgress     = 0.70
                        state.displayProgress = 0.70
                        state.scrollProgress  = 0.70
                    }
                    state.transition(to: .s3_dashboard)
                }
            }
            return nil

        // ── Action shortcuts — only fire when notch is expanded ─────────────
        // These are common editing shortcuts in other apps; guard stage prevents
        // accidental capture when the user is typing in Xcode/browser/Terminal.

        case 2 where hasCmd:   // ⌘D — mark done
            guard state.stage != .s0_idle else { return event }
            DispatchQueue.main.async { self.markDone(state: state) }
            return nil

        case 1 where hasCmd:   // ⌘S — skip
            guard state.stage != .s0_idle else { return event }
            DispatchQueue.main.async { self.skipTask(state: state) }
            return nil

        case 37 where hasCmd:  // ⌘L — later
            guard state.stage != .s0_idle else { return event }
            DispatchQueue.main.async {
                state.showContinuity("Moved later")
                state.collapse()
            }
            return nil

        case 14 where hasCmd:  // ⌘E — extend timer (Stage 1B only)
            guard state.stage == .s1b_timer else { return event }
            DispatchQueue.main.async {
                state.timerSecondsLeft += 15 * 60
                state.showContinuity("+15m added")
            }
            return nil

        default:
            return event
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

    // MARK: - Accessibility
    func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !UserDefaults.standard.bool(forKey: "notchly_setup_complete") {
                NotchState.shared.transition(to: .s4_chat)
            }
        }
    }

    deinit {
        if let ref = carbonChatRef     { UnregisterEventHotKey(ref) }
        if let m = globalChatMonitor   { NSEvent.removeMonitor(m) }
        if let m = localMonitor        { NSEvent.removeMonitor(m) }
    }
}
