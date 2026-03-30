import Foundation

/// Long-term user profile — stable preferences that evolve over days/weeks.
struct SemanticProfileData: Codable {
    var peakHours: [Int]          // hours with energy ≥ 7
    var preferredCategories: [TaskCategory]
    var classSchedule: [ClassSlot]
    var taskHabits: TaskHabits
    var onboardingAnswers: OnboardingAnswers?
}

struct ClassSlot: Codable {
    var weekday: Int   // 1=Sun … 7=Sat
    var startHour: Int
    var endHour: Int
    var name: String
}

struct TaskHabits: Codable {
    var avgCompletionRate: Double
    var avgPostponeRate: Double
    var preferredDuration: Int   // minutes
}

struct OnboardingAnswers: Codable {
    var wakeHour: Int
    var sleepHour: Int
    var isStudent: Bool
    var courseCount: Int
    var primaryGoal: String
}

final class SemanticProfile {

    static let shared = SemanticProfile()
    private let url = DirectorySetup.semanticProfile

    private(set) var data: SemanticProfileData = SemanticProfileData(
        peakHours: [9, 10, 11, 14, 15, 16],
        preferredCategories: [.deepWork, .study],
        classSchedule: [],
        taskHabits: TaskHabits(
            avgCompletionRate: 0.65,
            avgPostponeRate: 0.15,
            preferredDuration: 45
        ),
        onboardingAnswers: nil
    )

    private init() { load() }

    func save() {
        guard let d = try? JSONEncoder().encode(data) else { return }
        try? d.writeAtomically(to: url)
    }

    private func load() {
        guard let raw = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SemanticProfileData.self, from: raw) else { return }
        data = decoded
    }

    func update(_ block: (inout SemanticProfileData) -> Void) {
        block(&data)
        save()
    }
}
