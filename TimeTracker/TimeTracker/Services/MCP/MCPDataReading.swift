import Foundation

/// The read-only slice of local storage the MCP tools need, as an `async` protocol so
/// implementations can live off the main actor.
///
/// Deliberately *not* `LocalStorageService`: that one is `@MainActor` and wraps the UI's
/// `ModelContext`, which request handlers must never touch. See `SwiftDataMCPDataStore`.
protocol MCPDataReading: Sendable {
    func fetchTasks() async -> [TaskItem]
    func fetchTags() async -> [TagItem]
}
