import Foundation

/// The free-text task search predicate, shared by the Main Window search field and
/// any other caller that needs to resolve a rough task name — so the two can't drift.
enum TaskSearch {
    /// Matches case-insensitively against both the title and the description.
    /// An empty or whitespace-only query matches everything.
    static func matches(_ task: TaskItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return task.title.localizedCaseInsensitiveContains(trimmed)
            || task.taskDescription.localizedCaseInsensitiveContains(trimmed)
    }

    /// Filters `tasks` by `query`, preserving their order. An empty or
    /// whitespace-only query returns everything unfiltered.
    static func filter(_ tasks: [TaskItem], query: String) -> [TaskItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tasks }
        return tasks.filter { matches($0, query: trimmed) }
    }
}
