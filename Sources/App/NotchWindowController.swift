import AppKit
import SwiftUI

// MARK: - NotchDimensions (cached — never call NSScreen in SwiftUI body)

final class NotchDimensions {
    static let shared = NotchDimensions()

    private(set) var notchH: CGFloat = 38
    private(set) var notchW: CGFloat = 185
    private(set) var screenMidX: CGFloat = 960
    private(set) var screenMaxY: CGFloat = 900

    private init() {
        recalculate()
    }

    func recalculate() {
        guard let screen = notchScreen() else { return }
        let insets = screen.safeAreaInsets
        if insets.top > 0 {
            notchH = insets.top
        } else {
            notchH = 32  // fallback
        }
        // notchW approximated from safe area; clamp to known range
        notchW = max(120, min(220, notchH > 30 ? 185 : 150))
        screenMidX = screen.frame.midX
        screenMaxY = screen.frame.maxY
    }

    private func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

// MARK: - NotchPanel

final class NotchPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static func make() -> NotchPanel {
        let dims = NotchDimensions.shared

        let WIN_W: CGFloat = 720
        let WIN_H: CGFloat = 480

        let x = dims.screenMidX - WIN_W / 2
        let y = dims.screenMaxY - WIN_H

        let panel = NotchPanel(
            contentRect: NSRect(x: x, y: y, width: WIN_W, height: WIN_H),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .ignoresCycle, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        return panel
    }
}

// MARK: - NotchWindowController

final class NotchWindowController: NSWindowController {

    private var state: NotchState { NotchState.shared }
    private var screenChangeObserver: NSObjectProtocol?

    init() {
        let panel = NotchPanel.make()
        super.init(window: panel)
        setupContent()
        setupScreenObserver()
    }

    required init?(coder: NSCoder) { nil }

    private func setupContent() {
        guard let panel = window as? NotchPanel else { return }
        let rootView = NotchRootView()
            .environmentObject(NotchState.shared)
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        panel.orderFrontRegardless()
    }

    private func setupScreenObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    private func handleScreenChange() {
        NotchDimensions.shared.recalculate()
        repositionWindow()
    }

    private func repositionWindow() {
        let dims = NotchDimensions.shared
        let WIN_W: CGFloat = 720
        let WIN_H: CGFloat = 480
        let x = dims.screenMidX - WIN_W / 2
        let y = dims.screenMaxY - WIN_H
        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }

    deinit {
        if let obs = screenChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
