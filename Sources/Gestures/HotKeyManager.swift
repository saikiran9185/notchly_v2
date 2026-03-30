import AppKit
import SwiftUI
import Carbon

/// Registers global hotkeys via Carbon RegisterEventHotKey.
/// More reliable than NSEvent monitors for cross-app hotkeys.
///
/// Hotkeys (spec Part 7):
///   ⌘⇧Space → openStage4         (Space=49 cmd=256 shift=512)
///   ⌘Space  → toggleS3            (Space=49 cmd=256)
///   ⌘D      → markTaskDone        (D=2)
///   ⌘S      → skipCurrentTask     (S=1)
///   ⌘L      → laterTask           (L=37)
///   ⌘E      → extendTimer+15      (E=14)
///   Y       → primaryAction        (Y=16)
///   Esc     → collapseToS0         (Esc=53)
final class HotKeyManager {

    static let shared = HotKeyManager()
    private var refs: [EventHotKeyRef?] = []
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    private init() {}

    // MARK: - Start

    func register() {
        checkAccessibility()
        installEventHandler()
        registerAll()
    }

    // MARK: - Hotkey table

    private struct HKSpec {
        let keyCode: UInt32
        let modifiers: UInt32
        let action: () -> Void
    }

    private lazy var specs: [HKSpec] = [
        HKSpec(keyCode: 49, modifiers: UInt32(cmdKey | shiftKey)) { HotKeyManager.openS4() },   // ⌘⇧Space
        HKSpec(keyCode: 49, modifiers: UInt32(cmdKey))            { HotKeyManager.toggleS3() },  // ⌘Space
        HKSpec(keyCode:  2, modifiers: UInt32(cmdKey))            { HotKeyManager.taskDone() },  // ⌘D
        HKSpec(keyCode:  1, modifiers: UInt32(cmdKey))            { HotKeyManager.taskSkip() },  // ⌘S
        HKSpec(keyCode: 37, modifiers: UInt32(cmdKey))            { HotKeyManager.taskLater() }, // ⌘L
        HKSpec(keyCode: 14, modifiers: UInt32(cmdKey))            { HotKeyManager.extendTimer()}, // ⌘E
        HKSpec(keyCode: 16, modifiers: 0)                         { HotKeyManager.primaryAction()}, // Y
        HKSpec(keyCode: 53, modifiers: 0)                         { HotKeyManager.collapse() },  // Esc
    ]

    // MARK: - Registration

    private func installEventHandler() {
        var evType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                   eventKind:  UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            { _, event, _ -> OSStatus in
                                HotKeyManager.shared.handleEvent(event)
                                return noErr
                            },
                            1, &evType, nil, &handler)
    }

    private func registerAll() {
        for (index, spec) in specs.enumerated() {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4E4C5932), id: UInt32(index))  // 'NLY2'
            RegisterEventHotKey(spec.keyCode, spec.modifiers, hkID,
                                GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }

    private func handleEvent(_ event: EventRef?) {
        var hkID = EventHotKeyID()
        guard let event = event,
              GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                EventParamType(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID) == noErr,
              hkID.signature == OSType(0x4E4C5932),
              Int(hkID.id) < specs.count
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.specs[Int(hkID.id)].action()
        }
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    // MARK: - Actions (static so Carbon callback can reach them)

    static func openS4() {
        let s = NotchState.shared
        withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
            s.stage = .s4_chat
        }
    }

    static func toggleS3() {
        let s = NotchState.shared
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
            s.stage = s.stage == .s3_dashboard ? .s0_idle : .s3_dashboard
        }
    }

    static func taskDone() {
        guard let task = NotchState.shared.currentTask else { return }
        ActionEngine.shared.taskCompleted(task: task)
    }

    static func taskSkip() {
        ActionEngine.shared.dismissCurrentAlert()
    }

    static func taskLater() {
        guard let task = NotchState.shared.currentTask else { return }
        ActionEngine.shared.postponeTask(task)
    }

    static func extendTimer() {
        guard NotchState.shared.stage == .s1b_timer else { return }
        NotchState.shared.timerSecondsRemaining += 15 * 60
        NotchState.shared.showBanner("+15 min added")
    }

    static func primaryAction() {
        ActionEngine.shared.acceptCurrentAlert()
    }

    static func collapse() {
        NotchState.shared.collapseToIdle()
    }
}
