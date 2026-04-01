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
        notchH = max(notchH, 28)
        notchW = 162  // M3 14" hardware spec
        screenMidX = screen.frame.midX
        screenMaxY = screen.frame.maxY
    }

    func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

// MARK: - Continuous Math Helpers
enum NotchMath {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    static func smoothstep(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        return clamped * clamped * (3 - 2 * clamped)
    }

    static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        return 1 - pow(1 - clamped, 3)
    }

    static func easeOutExpo(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        return clamped == 1 ? 1 : 1 - pow(2, -10 * clamped)
    }
}

// MARK: - NotchlyLayout (Continuous Progress Model)
struct NotchlyLayout {
    let progress: CGFloat

    static let maxWidth: CGFloat = 520
    static let snapTargets: [CGFloat] = [0.0, 0.12, 0.40, 0.70, 1.0]

    var width: CGFloat {
        let dims = NotchDimensions.shared
        let base = NotchMath.lerp(dims.notchW, Self.maxWidth, NotchMath.easeOutCubic(progress))
        return min(base, NotchWindowController.WIN_W - 40)
    }

    var height: CGFloat {
        let dims = NotchDimensions.shared
        // Piecewise linear — matches actual stage content heights
        // s0=0, s1_5=70, s2a=130, s3=255, s4=330
        let breakpoints: [(p: CGFloat, extra: CGFloat)] = [
            (0.0, 0), (0.12, 70), (0.40, 130), (0.70, 255), (1.0, 330)
        ]
        let p = max(0, min(1, progress))
        for i in 1..<breakpoints.count {
            let lo = breakpoints[i-1], hi = breakpoints[i]
            if p <= hi.p {
                let t = (p - lo.p) / (hi.p - lo.p)
                return dims.notchH + lo.extra + (hi.extra - lo.extra) * t
            }
        }
        return dims.notchH + 330
    }

    var bottomRadius: CGFloat {
        NotchMath.lerp(10, 24, NotchMath.smoothstep(progress))
    }

    var topRadius: CGFloat {
        0.0
    }

    var horizontalPadding: CGFloat {
        NotchMath.lerp(12, 14, progress)
    }

    var bottomPadding: CGFloat {
        NotchMath.lerp(8, 14, progress)
    }

    var contentScale: CGFloat {
        NotchMath.lerp(0.92, 1.0, progress)
    }

    var shadowOpacity: CGFloat {
        let soft = NotchMath.smoothstep(max(0, min(1, (progress - 0.4) * 2)))
        let hard = NotchMath.smoothstep(max(0, min(1, (progress - 0.7) * 3)))
        return 0.15 * soft + 0.1 * hard
    }

    var shadowRadius: CGFloat {
        let soft = NotchMath.smoothstep(max(0, min(1, (progress - 0.4) * 2)))
        return NotchMath.lerp(0, 8, soft)
    }

    var shadowY: CGFloat {
        let soft = NotchMath.smoothstep(max(0, min(1, (progress - 0.4) * 2)))
        return NotchMath.lerp(0, 4, soft)
    }

    var headerOpacity: CGFloat {
        NotchMath.smoothstep(max(0, (progress - 0.1) * 1.5))
    }

    var bodyOpacity: CGFloat {
        NotchMath.smoothstep(max(0, (progress - 0.3) * 1.2))
    }

    var chatOpacity: CGFloat {
        NotchMath.smoothstep(max(0, (progress - 0.7) * 2.0))
    }

    func nearestSnapTarget() -> CGFloat {
        let targets = NotchlyLayout.snapTargets
        var nearest = targets[0]
        var minDist = abs(progress - nearest)
        for target in targets {
            let dist = abs(progress - target)
            if dist < minDist {
                minDist = dist
                nearest = target
            }
        }
        return nearest
    }

    func crossedSnapTarget(from previous: CGFloat) -> CGFloat? {
        let targets = NotchlyLayout.snapTargets
        for target in targets {
            if (previous < target && progress >= target) || (previous > target && progress <= target) {
                return target
            }
        }
        return nil
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
