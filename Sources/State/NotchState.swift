import SwiftUI
import Combine

/// Single ObservableObject source of truth for the entire app.
final class NotchState: ObservableObject {

    static let shared = NotchState()

    // MARK: - Stage
    @Published var stage: NotchStage = .s0_idle

    // MARK: - Current alert / task
    @Published var currentAlert: NotchAlert?
    @Published var currentTask: NotchTask?
    @Published var nextTask: NotchTask?
    @Published var taskQueue: [NotchTask] = []

    // MARK: - Missed alerts
    @Published var missedAlerts: [MissedAlert] = []

    // MARK: - Timer (S1B)
    @Published var timerSecondsRemaining: Int = 0
    @Published var timerIsPaused: Bool = false
    @Published var timerTaskName: String = ""

    // MARK: - Context
    @Published var context: ContextSnapshot = ContextSnapshot()

    // MARK: - Continuity banner
    @Published var continuityMessage: String = ""
    @Published var showContinuityBanner: Bool = false

    // MARK: - Swipe gesture state
    @Published var swipeXOffset: CGFloat = 0
    @Published var swipeGreenWashOpacity: Double = 0
    @Published var swipeGrayWashOpacity: Double = 0
    @Published var swipeRightBtnScale: CGFloat = 1.0
    @Published var swipeLeftBtnScale: CGFloat = 1.0

    // MARK: - S4 chat
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatIsPinned: Bool = false
    @Published var chatIsAIResponding: Bool = false

    // MARK: - Onboarding
    @Published var setupComplete: Bool = UserDefaults.standard.bool(forKey: "notchly_setup_complete")

    // MARK: - Affordance nudge
    var swipeHintShown: Bool {
        get { UserDefaults.standard.bool(forKey: "notchly_swipe_hint_shown") }
        set { UserDefaults.standard.set(newValue, forKey: "notchly_swipe_hint_shown") }
    }

    private init() {}

    // MARK: - Stage transitions

    func transition(to newStage: NotchStage) {
        guard newStage != stage else { return }
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                self?.stage = newStage
            }
        }
    }

    func collapseToIdle() {
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                self?.stage = .s0_idle
            }
        }
    }

    // MARK: - Continuity banner

    func showBanner(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.continuityMessage = message
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                self?.showContinuityBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.showContinuityBanner = false
                }
            }
        }
    }

    // MARK: - Missed alerts

    func addMissed(_ alert: NotchAlert) {
        let missed = MissedAlert(id: UUID(), alert: alert, missedAt: Date())
        DispatchQueue.main.async { [weak self] in
            self?.missedAlerts.append(missed)
        }
    }

    func clearAllMissed() {
        DispatchQueue.main.async { [weak self] in
            self?.missedAlerts.removeAll()
        }
    }
}

// MARK: - Chat model

struct ChatMessage: Identifiable {
    let id = UUID()
    var role: ChatRole
    var text: String
    var timestamp: Date = Date()
    var actionCard: ChatActionCard?
}

enum ChatRole {
    case user, assistant
}

struct ChatActionCard {
    var type: ActionCardType
    var rows: [ActionCardRow]
    var replyButtons: [String]
}

enum ActionCardType {
    case updatedQueue, timeline, singleTask, question
}

struct ActionCardRow {
    var label: String
    var value: String
    var color: String
}
