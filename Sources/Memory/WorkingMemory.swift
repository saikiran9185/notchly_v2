import Foundation

/// Short-term working memory — survives restart.
/// Stored at ~/notchly/v2/working_memory.json
final class WorkingMemory {

    static let shared = WorkingMemory()
    private let url = DirectorySetup.workingMemory

    private var store: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.notchly.working_memory")

    private init() {
        load()
    }

    subscript(key: String) -> String? {
        get { queue.sync { store[key] } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.store[key] = newValue
                self?.persist()
            }
        }
    }

    // MARK: - Private

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        store = dict
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.writeAtomically(to: url)
    }
}
