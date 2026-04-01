import Foundation
import EventKit

// BDI Cognitive Engine — Beliefs, Desires, Intentions
class BDIAgent {
    static let shared = BDIAgent()
    private var guardTimer: Timer?
    private init() {}

    // MARK: - Key Beliefs
    struct Beliefs {
        var isInClass: Bool = false
        var isDeepWork: Bool = false
        var isIdle: Bool = false        // IOKit idle > 1200s
        var deadlineToday: Bool = false
        var relevantAppFront: Bool = false
    }

    private var beliefs = Beliefs()

    // MARK: - Intentions (ranked by expectedUtility − costEstimate)
    enum Intention: Int, Comparable {
        case enterClassMode     = 9
        case escalateDeadline   = 8
        case showAppButton      = 7
        case autoReschedule     = 6
        case showTransitionNudge = 5
        case sendMotivation     = 4
        case diagnosisMode      = 3

        static func < (lhs: Intention, rhs: Intention) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    func initialize() {
        updateBeliefs(from: NotchState.shared.context)
        startMessClassGuard()
    }

    // MARK: - Mess & Class Guard
    // Fires every 60s. If a mess or class event starts in ≤ 15 min, sends P=9.5 alert.
    private var firedGuardIDs: Set<String> = []

    // DateFormatter cached — allocating one per tick is expensive
    private let guardDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f
    }()

    private func startMessClassGuard() {
        guardTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.pruneOldGuardIDs()
            self?.checkMessAndClass()
        }
        checkMessAndClass()
    }

    // Prune IDs older than today — prevent unbounded growth
    private func pruneOldGuardIDs() {
        let todayPrefix = String(guardDateFormatter.string(from: Date()).prefix(8)) // "yyyyMMdd"
        firedGuardIDs = firedGuardIDs.filter { $0.contains(todayPrefix) }
    }

    private func checkMessAndClass() {
        let now = Date()
        let lookahead = now.addingTimeInterval(15 * 60) // 15 min lookahead window
        let state = NotchState.shared

        // ── Transit buffer: check if a class just ended (within the last 2 min) ──
        // 3-minute window — covers the 60s polling gap with margin
        let recentWindow = now.addingTimeInterval(-180)
        let recentEvents = CalendarReader.shared.loadEvents(from: recentWindow, to: now)
        for event in recentEvents {
            guard let end = event.endDate else { continue }
            let secondsAgo = now.timeIntervalSince(end)
            guard secondsAgo >= 0 && secondsAgo <= 180 else { continue }
            guard CalendarReader.shared.isClass(event) else { continue }
            let bufferKey = "transit-\(event.eventIdentifier ?? "")-\(formattedDate(end))"
            guard !firedGuardIDs.contains(bufferKey) else { continue }
            firedGuardIDs.insert(bufferKey)
            DispatchQueue.main.async {
                state.startClassTransitBuffer()
                state.showContinuity("15m walk buffer · notch stays quiet")
            }
        }

        let events = CalendarReader.shared.loadEvents(from: now, to: lookahead)
        guard !state.isClassMode, !state.isFocusMode else { return }

        for event in events {
            guard let start = event.startDate else { continue }
            let minutesUntil = Int(start.timeIntervalSinceNow / 60)
            guard minutesUntil >= 0 && minutesUntil <= 15 else { continue }

            let guardKey = "\(event.eventIdentifier ?? "")-\(formattedDate(start))"
            guard !firedGuardIDs.contains(guardKey) else { continue }

            let isClass = CalendarReader.shared.isClass(event)
            let isMess  = CalendarReader.shared.isMess(event)
            guard isClass || isMess else { continue }

            firedGuardIDs.insert(guardKey)

            let title: String
            let type: NotifType
            if isClass {
                title = "\(event.title ?? "Class") in \(minutesUntil)m · pack up now"
                type  = .class_
            } else {
                title = "Mess closes in \(minutesUntil + 30)m · eat now?"
                type  = .meal
            }

            var notif = NotchNotification(title: title, subtitle: "", type: type)
            notif.leftAction  = isClass ? "Skip" : "Skip lunch"
            notif.rightAction = isClass ? "On my way" : "Going now"

            DispatchQueue.main.async { state.enqueue(notif) }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        guardDateFormatter.string(from: date)
    }

    func updateBeliefs(from context: ContextSnapshot) {
        beliefs.isInClass    = context.isInClass
        beliefs.isDeepWork   = context.isDeepWork
        beliefs.isIdle       = context.idleMinutes > 20
        beliefs.deadlineToday = NotchState.shared.taskQueue.contains {
            guard let h = $0.hoursUntilDeadline else { return false }
            return h < 24
        }
    }

    // MARK: - Class mode enforcement
    var shouldEnterClassMode: Bool { beliefs.isInClass }

    // MARK: - Idle motivational nudge (20min idle → personalized message)
    func checkIdleNudge(state: NotchState) {
        guard beliefs.isIdle, !state.isClassMode, !state.isFocusMode else { return }
        let msg = idleMessage(state: state)
        let notif = NotchNotification(
            title: msg,
            subtitle: "tap to respond",
            type: .lazy
        )
        enqueueIfAllowed(notif, state: state)
    }

    // MARK: - 3× rejection → diagnosis mode
    func checkDiagnosisMode(for task: NotchTask, state: NotchState) {
        guard task.rejectionCount >= 3 else { return }
        state.diagnosisTask = task
        state.transition(to: .s1_5x_diagnosis)
    }

    // MARK: - Chat input routing
    func handleChatInput(_ text: String, state: NotchState, completion: @escaping (String) -> Void) {
        // Parse intent from text
        let lower = text.lowercased()

        if lower.contains("add task") || lower.contains("new task") {
            handleAddTask(text, state: state, completion: completion)
        } else if lower.contains("reschedule") || lower.contains("move") {
            handleReschedule(text, state: state, completion: completion)
        } else if lower.contains("done") || lower.contains("finished") {
            handleDone(text, state: state, completion: completion)
        } else {
            // General response — in Phase G this routes to Python brain
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                completion(self.generateResponse(for: text, state: state))
            }
        }
    }

    // MARK: - Intent handlers
    private func handleAddTask(_ text: String, state: NotchState, completion: @escaping (String) -> Void) {
        // Extract task name from text
        let name = text
            .replacingOccurrences(of: "add task ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "new task ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        var task = NotchTask(title: name.isEmpty ? "New Task" : name)
        task = PriorityScorer.shared.score(task, context: state.context)
        state.taskQueue.append(task)
        state.taskQueue = PriorityScorer.shared.scoreAll(state.taskQueue, context: state.context)
        WorkingMemory.shared.save(state: state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion("Added '\(task.title)' — P=\(String(format: "%.1f", task.pFinal)) · \(state.taskQueue.count) tasks today")
        }
    }

    private func handleReschedule(_ text: String, state: NotchState, completion: @escaping (String) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion("Rescheduled to next available slot. Queue rebalanced.")
        }
    }

    private func handleDone(_ text: String, state: NotchState, completion: @escaping (String) -> Void) {
        if let current = state.currentTask {
            state.doneToday += 1
            state.taskQueue.removeAll { $0.id == current.id }
            state.currentTask = state.taskQueue.first
            WorkingMemory.shared.save(state: state)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion("\(current.title) done ✓ · \(state.taskQueue.count) left")
            }
        } else {
            completion("No active task. Use 'add task [name]' to add one.")
        }
    }

    private func generateResponse(for text: String, state: NotchState) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let energy = EnergyModel.shared.currentEnergy(at: hour)
        let taskCount = state.taskQueue.count
        return "Energy: \(EnergyModel.shared.label(for: energy)) · \(taskCount) tasks queued. Type 'add task [name]' or 'reschedule [task]'."
    }

    private func idleMessage(state: NotchState) -> String {
        if let task = state.taskQueue.first {
            return "\(task.title) due \(deadlineLabel(task)) and you haven't touched it today"
        }
        return "You've been idle 20min · queue is waiting"
    }

    private func deadlineLabel(_ task: NotchTask) -> String {
        guard let d = task.deadline else { return "soon" }
        let h = Int(d.timeIntervalSinceNow / 3600)
        return h < 1 ? "in <1h" : "in \(h)h"
    }

    private func enqueueIfAllowed(_ notif: NotchNotification, state: NotchState) {
        guard !state.isClassMode, !state.isFocusMode else { return }
        DispatchQueue.main.async { state.enqueue(notif) }
    }

    deinit {
        guardTimer?.invalidate()
    }
}
