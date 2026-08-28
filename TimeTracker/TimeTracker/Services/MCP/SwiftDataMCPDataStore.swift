import Foundation
import SwiftData

/// Reads the app's SwiftData store from outside the main actor, for MCP request handlers.
///
/// SwiftData's `ModelContext` is not thread-safe and the UI's context belongs to the main
/// actor, so handlers get their own. Two properties make this safe:
///
/// 1. The actor serializes every read, so no context is ever touched concurrently.
/// 2. Each read creates a **fresh** `ModelContext` from the shared `ModelContainer`,
///    rather than holding one for the actor's lifetime the way `@ModelActor` does. A
///    long-lived context keeps a row cache that can serve stale values after the UI's
///    context writes; a per-request context always reads through to the store. At this
///    app's data volume that costs nothing, and it makes "handlers never see stale data"
///    structural rather than a thing to remember.
///
/// `@Model` entities never leave this actor — only the `Sendable` domain value types do.
final actor SwiftDataMCPDataStore: MCPDataReading {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchTasks() -> [TaskItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let tasks = (try? context.fetch(descriptor)) ?? []
        return tasks.map { SwiftDataItemMapper.task($0) }
    }

    func fetchTags() -> [TagItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TagEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let tags = (try? context.fetch(descriptor)) ?? []
        return tags.map { SwiftDataItemMapper.tag($0) }
    }
}
