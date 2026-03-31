import AppKit
import SwiftUI
import Carbon

// MARK: - NotchDimensions (never call NSScreen inside SwiftUI body — cache here)
final class NotchDimensions {
    static let shared = NotchDimensions()

    private(set) var notchH: CGFloat = 38
    private(set) var notchW: CGFloat = 185
    private(set) var screenMidX: CGFloat = 960
    private(set) var screenMaxY: CGFloat = 900

    private init() { recalculate() }

    func recalculate() {
        guard let screen = notchScreen() else { return }
        let inset = screen.safeAreaInsets.top
        notchH = inset > 0 ? inset : 32
        notchH = max(notchH, 28)    // minimum 28pt fallback
        notchW = 185                 // standard MBP 14/16 notch width
        screenMidX = screen.frame.midX
        screenMaxY = screen.frame.maxY
    }

    func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

// MARK: - NotchPanel
class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - NotchWindowController
class NotchWindowController: NSWindowController {
    static let WIN_W: CGFloat = 720
    static let WIN_H: CGFloat = 480

    init() {
        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        super.init(window: panel)

        let rootView = NotchRootView().environmentObject(NotchState.shared)
        panel.contentView = NSHostingView(rootView: rootView)

        repositionWindow()
    }

    required init?(coder: NSCoder) { fatalError("use init()") }

    func repositionWindow() {
        guard let screen = NotchDimensions.shared.notchScreen() else { return }
        NotchDimensions.shared.recalculate()
        let x = screen.frame.midX - NotchWindowController.WIN_W / 2
        let y = screen.frame.maxY - NotchWindowController.WIN_H
        window?.setFrame(
            NSRect(x: x, y: y,
                   width: NotchWindowController.WIN_W,
                   height: NotchWindowController.WIN_H),
            display: true
        )
        window?.orderFrontRegardless()
    }
}
