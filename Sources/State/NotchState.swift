import SwiftUI
import Combine

class NotchState: ObservableObject {
    static let shared = NotchState()

    // MARK: - Stage
    @Published var stage: NotchStage = .s0_idle

    // MARK: - Active content
    @Published var currentNotification: NotchNotification?
    @Published var currentTask: NotchTask?
    @Published var activeTimerTask: NotchTask?
    @Published var taskQueue: [NotchTask] = []
    @Published var missedNotifications: [NotchNotification] = []

    // MARK: - Context
    @Published var context: ContextSnapshot = ContextSnapshot()

    // MARK: - Focus / class state
    @Published var isDeepFocus: Bool = false
    @Published var isClassMode: Bool = false
    @Published var isFocusMode: Bool = false
    @Published var focusModeEndTime: Date?

    // MARK: - Timer (Stage 1B)
    @Published var timerSecondsLeft: Int = 0
    @Published var timerIsPaused: Bool = false

    // MARK: - Swipe physics
    @Published var swipeXOffset: CGFloat = 0
    @Published var swipePhase: SwipePhase = .idle
    @Published var swipeRatio: Double = 0     // 0.0–1.0

    // MARK: - Continuity banner
    @Published var continuityMessage: String = ""
    @Published var showContinuityBanner: Bool = false

    // MARK: - Diagnosis mode
    @Published var diagnosisTask: NotchTask?

    // MARK: - Continuous scroll progress layers
    // rawProgress: physics layer (gesture accumulation)
    // displayProgress: visual layer (micro-resistance + hover applied)
    // scrollProgress: backward-compatibility alias
    @Published var rawProgress: CGFloat = 0.0
    @Published var displayProgress: CGFloat = 0.0
    @Published var scrollProgress: CGFloat = 0.0

    // MARK: - Day stats
    @Published var doneToday: Int = 0
    @Published var leftToday: Int = 0

    // MARK: - Pulse / AI bridge state
    @Published var aiStatus: String = "unknown"   // "ready" | "offline" | "unknown"
    @Published var pulseMissedCount: Int = 0

    // MARK: - Chat state (for Python brain integration)
    @Published var chatMessages: [ChatMessage] = []
    @Published var aiIsThinking: Bool = false
    @Published var chatIsPinned: Bool = false

    func receiveChatReply(_ text: String) {
        let msg = ChatMessage(text: text, isUser: false)
        chatMessages.append(msg)
        aiIsThinking = false
        chatIsPinned = false
    }

    // MARK: - Transit buffer (15 min after class ends — blocks scroll expansion)
    @Published var classTransitBufferUntil: Date?

    func startClassTransitBuffer() {
        classTransitBufferUntil = Date().addingTimeInterval(15 * 60)
    }

    var isInTransitBuffer: Bool {
        guard let end = classTransitBufferUntil else { return false }
        return Date() < end
    }

    private var continuityTimer: Timer?
    private init() {}

    // MARK: - World state (from Rust Pulse)
    func applyWorldState(_ world: WorldState) {
        aiStatus = world.aiStatus
        pulseMissedCount = world.missedCount
        taskQueue   = world.taskQueue.map { $0.toNotchTask() }
        currentTask = world.currentTask?.toNotchTask()
        doneToday   = taskQueue.filter { $0.isCompleted }.count
        leftToday   = taskQueue.filter { !$0.isCompleted }.count
    }

    // MARK: - Stage transition
    func transition(to newStage: NotchStage,
                    spring: Animation = .spring(response: 0.42, dampingFraction: 0.68)) {
        withAnimation(spring) { stage = newStage }
    }

    func collapse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
            stage = .s0_idle
            rawProgress = 0
            displayProgress = 0
            scrollProgress = 0
        }
        // Reset accumulator so next scroll starts fresh
        ScrollDepthHandler.shared.resetAccumulator()
    }

    // MARK: - Continuity banner
    func showContinuity(_ message: String) {
        continuityMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            showContinuityBanner = true
        }
        continuityTimer?.invalidate()
        continuityTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.showContinuityBanner = false
            }
        }
    }

    deinit {
        continuityTimer?.invalidate()
    }

    // MARK: - Notification queue management
    func enqueue(_ notification: NotchNotification) {
        if stage == .s0_idle || stage == .s1_5_hover {
            currentNotification = notification
            transition(to: .s1a_notification)
        }
        // If already showing, EVR/InterruptionGuard will retry in 5min
    }

    func dismissCurrentNotification() {
        if let notif = currentNotification {
            missedNotifications.append(notif)
        }
        currentNotification = nil
        collapse()
    }

    func clearMissed() {
        missedNotifications.removeAll()
    }

    // MARK: - Task timer (Stage 1B)
    func startTimer(for task: NotchTask) {
        activeTimerTask = task
        timerSecondsLeft = task.estimatedMinutes * 60
        timerIsPaused = false
        transition(to: .s1b_timer)
    }
}

enum SwipePhase: Equatable {
    case idle, pulling, threshold, committed
}
