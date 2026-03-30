import AppKit

/// Monitors global mouse movement and fires enter/exit events
/// for the 400×75pt hover zone centered on the notch.
///
/// Spec:
///   zone w=400pt  h=75pt
///   position: centerX=screenMidX  top=screen.maxY−75pt
final class HoverZoneMonitor {

    static let shared = HoverZoneMonitor()

    private var globalMonitor: Any?
    private(set) var isCursorInZone = false

    var onEnter: (() -> Void)?
    var onExit:  (() -> Void)?

    private init() {}

    // MARK: - Start / Stop

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.evaluate()
        }
        // Also track local (when app is key)
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.evaluate()
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
    }

    // MARK: - Zone geometry

    var hoverZone: NSRect {
        let dims = NotchDimensions.shared
        let w: CGFloat = 400
        let h: CGFloat = 75
        let x = dims.screenMidX - w / 2
        let y = dims.screenMaxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    var notchZone: NSRect {
        let dims = NotchDimensions.shared
        let w = dims.notchW + 20
        let h = dims.notchH + 10
        let x = dims.screenMidX - w / 2
        let y = dims.screenMaxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    func cursorInHoverZone() -> Bool {
        hoverZone.contains(NSEvent.mouseLocation)
    }

    func cursorInNotchZone() -> Bool {
        notchZone.contains(NSEvent.mouseLocation)
    }

    // MARK: - Private

    private func evaluate() {
        let inside = cursorInHoverZone()
        if inside && !isCursorInZone {
            isCursorInZone = true
            onEnter?()
        } else if !inside && isCursorInZone {
            isCursorInZone = false
            onExit?()
        }
    }
}
