import AppKit
import SwiftUI
import Foundation

// Stage canonical progress values — the exact geometry size for each stage
private extension NotchStage {
    var canonicalProgress: CGFloat {
        switch self {
        case .s0_idle:          return 0.0
        case .s1_5_hover:       return 0.12
        case .s1_5x_diagnosis:  return 0.12
        case .s1a_notification: return 0.15
        case .s1b_timer:        return 0.15
        case .s2a_nowcard:      return 0.40
        case .s2b_missed:       return 0.40
        case .s3_dashboard:     return 0.70
        case .s4_chat:          return 1.0
        }
    }
}

class ScrollDepthHandler {
    static let shared = ScrollDepthHandler()
    private init() {}

    private var globalMonitor: Any?
    private var localMonitor:  Any?
    private var mouseWheelTimer: Timer?

    private var accumulator:  CGFloat = 0
    private var velocity:     CGFloat = 0
    private var lastEventTime: Date   = Date()
    private var previousRawProgress: CGFloat = 0

    func resetAccumulator() {
        accumulator = 0
        velocity    = 0
        mouseWheelTimer?.invalidate()
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event); return event
        }
    }

    // MARK: - Main handler
    private func handle(_ event: NSEvent) {
        let monitor = HoverZoneMonitor.shared
        let inHoverZone = monitor.cursorInHoverZone()
        let inPillZone  = monitor.cursorInPillZone()
        let state       = NotchState.shared
        // BUG-25 fix: allow scroll from within the full pill area when already expanded,
        // not just the narrow 85pt trigger zone — prevents limbo stuck state on scroll-back
        guard inHoverZone || (inPillZone && state.stage != .s0_idle) else { return }
        guard !state.isInTransitBuffer else { accumulator = 0; velocity = 0; return }

        let phase     = event.phase
        let isPrecise = event.hasPreciseScrollingDeltas

        if phase == .began {
            // BUG-D fix: seed accumulator from current rawProgress so new gesture continues
            // from wherever the pill is — prevents instant collapse when starting a gesture at S3
            accumulator          = NotchState.shared.rawProgress * 200.0
            velocity             = 0
            previousRawProgress  = NotchState.shared.rawProgress
            lastEventTime        = Date()
            mouseWheelTimer?.invalidate()
        }

        let delta: CGFloat = isPrecise ? event.scrollingDeltaY : event.scrollingDeltaY * 8

        // Velocity EMA
        let now = Date()
        let dt  = now.timeIntervalSince(lastEventTime)
        if dt > 0 && dt < 0.2 {
            velocity = velocity * 0.6 + (delta / CGFloat(dt)) * 0.4
        }
        lastEventTime = now

        if phase == .changed || !isPrecise { accumulator += delta }

        // Physics
        var rawP = accumulator / 200.0
        let vNorm = min(abs(velocity) / 1000, 1)
        let vDir: CGFloat = velocity == 0 ? 0 : (velocity > 0 ? 1 : -1)
        rawP += vDir * sqrt(vNorm) * 0.04
        let clamped = max(0, min(1, rawP))

        // Visual
        let resisted = pow(clamped, 1.3)
        let hover    = HoverZoneMonitor.shared.hoverInfluence
        let display  = NotchMath.lerp(resisted, max(resisted, 0.12), hover)

        // Haptics
        let layout = NotchlyLayout(progress: clamped)
        if let crossed = layout.crossedSnapTarget(from: previousRawProgress) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            _ = crossed
        }
        previousRawProgress = clamped

        // Update state + HARD STOP stage snap
        // BUG-A fix: check both zones — pill-zone cursor is valid when expanded
        // (narrow trigger-only check dropped updates in the 222pt pill-only dead zone)
        DispatchQueue.main.async {
            let monitor = HoverZoneMonitor.shared
            guard monitor.cursorInHoverZone() || (monitor.cursorInPillZone() && NotchState.shared.stage != .s0_idle) else { return }
            NotchState.shared.rawProgress     = clamped
            NotchState.shared.displayProgress = display
            NotchState.shared.scrollProgress  = display
            self.updateStage(for: clamped)
        }

        // Trackpad end
        if phase == .ended || phase == .cancelled {
            finalizeScroll(clamped)
            accumulator = 0; velocity = 0
        }

        // Mouse wheel debounce
        if !isPrecise {
            let snap = clamped
            mouseWheelTimer?.invalidate()
            mouseWheelTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.finalizeScroll(snap)
                self?.accumulator = 0; self?.velocity = 0
            }
        }
    }

    // MARK: - Stage transition + HARD STOP
    private func updateStage(for p: CGFloat) {
        let state = NotchState.shared
        guard state.stage != .s1_5x_diagnosis else { return }

        let target: NotchStage
        if      p >= 0.70 { target = .s3_dashboard }
        else if p >= 0.40 {
            target = state.shouldShowMissedCard ? .s2b_missed : .s2a_nowcard
        }
        else if p >= 0.12 { target = .s1_5_hover   }
        else              { target = .s0_idle       }

        guard state.stage != target else { return }

        // Transition stage
        state.transition(to: target)

        // HARD STOP: lock geometry to this stage's canonical size
        let canonical = target.canonicalProgress
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            state.rawProgress     = canonical
            state.displayProgress = canonical
            state.scrollProgress  = canonical
        }
        // Sync accumulator so next scroll continues from here
        accumulator = canonical * 200.0
    }

    // MARK: - Finalize / snap
    private func finalizeScroll(_ clamped: CGFloat) {
        let state   = NotchState.shared
        let nearest = NotchlyLayout(progress: clamped).nearestSnapTarget()
        let dist    = abs(clamped - nearest)
        guard abs(velocity) < 50 && dist < 0.12 else { velocity = 0; return }

        // Snap to nearest and hard-stop geometry
        let targetStage = stageFor(nearest)
        let canonical   = targetStage.canonicalProgress

        DispatchQueue.main.async {
            // BUG-A fix: allow finalize when cursor is anywhere in the pill, not just trigger zone
            let mon = HoverZoneMonitor.shared
            guard mon.cursorInHoverZone() || (mon.cursorInPillZone() && state.stage != .s0_idle) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                state.rawProgress     = canonical
                state.displayProgress = canonical
                state.scrollProgress  = canonical
            }
            if state.stage != targetStage { state.transition(to: targetStage) }

            // Hard settle after spring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard mon.cursorInHoverZone() || (mon.cursorInPillZone() && state.stage != .s0_idle) else { return }
                if abs(state.displayProgress - canonical) < 0.02 {
                    state.displayProgress = canonical
                    state.scrollProgress  = canonical
                }
            }
        }
        velocity    = 0
        accumulator = canonical * 200.0
    }

    private func stageFor(_ p: CGFloat) -> NotchStage {
        if      p >= 0.70 { return .s3_dashboard }
        else if p >= 0.40 { return NotchState.shared.shouldShowMissedCard ? .s2b_missed : .s2a_nowcard }
        else if p >= 0.12 { return .s1_5_hover   }
        else              { return .s0_idle       }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
        mouseWheelTimer?.invalidate()
    }
}
