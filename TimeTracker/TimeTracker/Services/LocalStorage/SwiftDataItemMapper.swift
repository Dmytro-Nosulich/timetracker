import Foundation

/// Maps SwiftData `@Model` entities to the `Sendable` domain value types.
///
/// Shared by `SwiftDataLocalStorageService` (main context, UI) and
/// `SwiftDataMCPDataStore` (background context, MCP request handlers) so the two
/// cannot disagree about what a `TaskItem` contains.
///
/// Callers must invoke these on whatever isolation domain owns the entities'
/// `ModelContext` — the entities themselves never cross an isolation boundary, only
/// the value types returned here do.
enum SwiftDataItemMapper {

    static func task(_ task: TaskEntity) -> TaskItem {
        TaskItem(
            id: task.id,
            title: task.title,
            taskDescription: task.taskDescription,
            createdAt: task.createdAt,
            isArchived: task.isArchived,
            hourlyRate: task.hourlyRate,
            tags: task.tags.map { tag($0) },
            timeEntries: task.timeEntries.map { timeEntry($0) },
            totalTrackedTime: task.totalTrackedTime,
            trackedTimeToday: task.trackedTimeToday
        )
    }

    static func timeEntry(_ entry: TimeEntryEntity) -> TimeEntryItem {
        TimeEntryItem(
            id: entry.id,
            startDate: entry.startDate,
            endDate: entry.endDate,
            isManual: entry.isManual,
            note: entry.note
        )
    }

    static func tag(_ tag: TagEntity) -> TagItem {
        TagItem(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex,
            createdAt: tag.createdAt
        )
    }
}
