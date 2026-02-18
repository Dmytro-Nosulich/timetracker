import Foundation
import SwiftData

@MainActor
final class SwiftDataLocalStorageService: LocalStorageService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTasks() -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.map { mapTask($0) }
    }

    func fetchTags() -> [TagItem] {
        let descriptor = FetchDescriptor<TagEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        return tags.map { mapTag($0) }
    }

    @discardableResult
    func createTask(title: String, description: String, tagIds: [UUID]) -> TaskItem {
        let task = TaskEntity(title: title, taskDescription: description)

        if !tagIds.isEmpty {
            let tagDescriptor = FetchDescriptor<TagEntity>()
            let allTags = (try? modelContext.fetch(tagDescriptor)) ?? []
            task.tags = allTags.filter { tagIds.contains($0.id) }
        }

        modelContext.insert(task)
        try? modelContext.save()
        return mapTask(task)
    }

    func deleteTask(id: UUID) {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    func totalTrackedTimeToday() -> TimeInterval {
        let descriptor = FetchDescriptor<TaskEntity>()
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.reduce(0) { $0 + $1.trackedTimeToday }
    }

    // MARK: - Time Entry Operations

    @discardableResult
    func createTimeEntry(startDate: Date, for taskId: UUID) -> TimeEntryItem? {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == taskId }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return nil }
        let entry = TimeEntryEntity(task: task, startDate: startDate)
        modelContext.insert(entry)
        try? modelContext.save()
        return mapTimeEntry(entry)
    }

    func closeTimeEntry(id: UUID, endDate: Date) {
        let descriptor = FetchDescriptor<TimeEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entry = try? modelContext.fetch(descriptor).first {
            entry.endDate = endDate
            try? modelContext.save()
        }
    }

    func fetchOpenTimeEntry() -> (entry: TimeEntryItem, taskId: UUID)? {
        let descriptor = FetchDescriptor<TimeEntryEntity>(
            predicate: #Predicate { $0.endDate == nil }
        )
        guard let entity = try? modelContext.fetch(descriptor).first,
              let taskId = entity.task?.id else { return nil }
        return (mapTimeEntry(entity), taskId)
    }

    func trackedTimeToday(for taskId: UUID) -> TimeInterval {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == taskId }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return 0 }
        return task.trackedTimeToday
    }

    func fetchTask(id: UUID) -> TaskItem? {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return nil }
        return mapTask(task)
    }

    func deleteTimeEntry(id: UUID) {
        let descriptor = FetchDescriptor<TimeEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entry = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    // MARK: - Mapping

    private func mapTask(_ task: TaskEntity) -> TaskItem {
        TaskItem(
            id: task.id,
            title: task.title,
            taskDescription: task.taskDescription,
            createdAt: task.createdAt,
            isArchived: task.isArchived,
            hourlyRate: task.hourlyRate,
            tags: task.tags.map { mapTag($0) },
            timeEntries: task.timeEntries.map { mapTimeEntry($0) },
            totalTrackedTime: task.totalTrackedTime,
            trackedTimeToday: task.trackedTimeToday
        )
    }

    private func mapTimeEntry(_ entry: TimeEntryEntity) -> TimeEntryItem {
        TimeEntryItem(
            id: entry.id,
            startDate: entry.startDate,
            endDate: entry.endDate,
            isManual: entry.isManual,
            note: entry.note
        )
    }

    private func mapTag(_ tag: TagEntity) -> TagItem {
        TagItem(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex,
            createdAt: tag.createdAt
        )
    }
}
