import Testing
import Foundation
import SwiftData
@testable import TimeTracker

@MainActor
struct SwiftDataLocalStorageServiceTests {

    private func makeService() throws -> (SwiftDataLocalStorageService, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TrackerTask.self, TimeEntry.self, TagEntity.self,
            configurations: config
        )
        let context = container.mainContext
        let service = SwiftDataLocalStorageService(modelContext: context)
        return (service, context)
    }

    // MARK: - fetchTasks

    @Test func fetchTasksEmpty() throws {
        let (service, _) = try makeService()
        let tasks = service.fetchTasks()
        #expect(tasks.isEmpty)
    }

    @Test func fetchTasksReturnsMappedItems() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Test Task", taskDescription: "Description")
        context.insert(task)
        try context.save()

        let items = service.fetchTasks()
        #expect(items.count == 1)
        #expect(items.first?.title == "Test Task")
        #expect(items.first?.taskDescription == "Description")
    }

    @Test func fetchTasksSortedByCreatedAtDescending() throws {
        let (service, context) = try makeService()
        let older = TrackerTask(title: "Older")
        older.createdAt = Date(timeIntervalSince1970: 1000)
        let newer = TrackerTask(title: "Newer")
        newer.createdAt = Date(timeIntervalSince1970: 2000)
        context.insert(older)
        context.insert(newer)
        try context.save()

        let items = service.fetchTasks()
        #expect(items.count == 2)
        #expect(items.first?.title == "Newer")
        #expect(items.last?.title == "Older")
    }

    @Test func fetchTasksWithTags() throws {
        let (service, context) = try makeService()
        let tag = TagEntity(name: "Work", colorHex: "FF0000")
        context.insert(tag)
        let task = TrackerTask(title: "Tagged Task")
        task.tags = [tag]
        context.insert(task)
        try context.save()

        let items = service.fetchTasks()
        #expect(items.first?.tags.count == 1)
        #expect(items.first?.tags.first?.name == "Work")
    }

    // MARK: - fetchTags

    @Test func fetchTagsEmpty() throws {
        let (service, _) = try makeService()
        let tags = service.fetchTags()
        #expect(tags.isEmpty)
    }

    @Test func fetchTagsReturnsMappedItems() throws {
        let (service, context) = try makeService()
        let tag = TagEntity(name: "Design", colorHex: "00FF00")
        context.insert(tag)
        try context.save()

        let items = service.fetchTags()
        #expect(items.count == 1)
        #expect(items.first?.name == "Design")
        #expect(items.first?.colorHex == "00FF00")
    }

    // MARK: - createTask

    @Test func createTaskReturnsItem() throws {
        let (service, _) = try makeService()
        let item = service.createTask(title: "New", description: "Desc", tagIds: [])

        #expect(item.title == "New")
        #expect(item.taskDescription == "Desc")
        #expect(item.tags.isEmpty)
    }

    @Test func createTaskPersists() throws {
        let (service, _) = try makeService()
        service.createTask(title: "Persisted", description: "", tagIds: [])

        let fetched = service.fetchTasks()
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Persisted")
    }

    @Test func createTaskWithTags() throws {
        let (service, context) = try makeService()
        let tag = TagEntity(name: "Dev", colorHex: "0000FF")
        context.insert(tag)
        try context.save()

        let item = service.createTask(title: "With Tag", description: "", tagIds: [tag.id])

        #expect(item.tags.count == 1)
        #expect(item.tags.first?.name == "Dev")
    }

    @Test func createTaskWithNonExistentTagIds() throws {
        let (service, _) = try makeService()
        let item = service.createTask(title: "Task", description: "", tagIds: [UUID()])

        #expect(item.tags.isEmpty)
    }

    // MARK: - deleteTask

    @Test func deleteTaskRemovesIt() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "To Delete")
        context.insert(task)
        try context.save()
        let taskId = task.id

        service.deleteTask(id: taskId)

        let remaining = service.fetchTasks()
        #expect(remaining.isEmpty)
    }

    @Test func deleteTaskNonExistentIdDoesNotCrash() throws {
        let (service, _) = try makeService()
        service.deleteTask(id: UUID()) // Should not throw
    }

    // MARK: - totalTrackedTimeToday

    @Test func totalTrackedTimeTodayNoTasks() throws {
        let (service, _) = try makeService()
        #expect(service.totalTrackedTimeToday() == 0)
    }

    @Test func totalTrackedTimeTodayWithEntries() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let entry = TimeEntry(task: task, startDate: oneHourAgo, endDate: now)
        context.insert(entry)
        task.timeEntries = [entry]
        try context.save()

        let total = service.totalTrackedTimeToday()
        #expect(total >= 3599 && total <= 3601)
    }

    // MARK: - createTimeEntry

    @Test func createTimeEntryReturnsItem() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)
        try context.save()

        let entry = service.createTimeEntry(startDate: Date(), for: task.id)

        #expect(entry != nil)
        #expect(entry?.endDate == nil)
        #expect(entry?.isManual == false)
    }

    @Test func createTimeEntryReturnsNilForNonExistentTask() throws {
        let (service, _) = try makeService()

        let entry = service.createTimeEntry(startDate: Date(), for: UUID())

        #expect(entry == nil)
    }

    // MARK: - closeTimeEntry

    @Test func closeTimeEntrySetsEndDate() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)
        try context.save()

        let entry = service.createTimeEntry(startDate: Date(), for: task.id)!
        let endDate = Date()
        service.closeTimeEntry(id: entry.id, endDate: endDate)

        let openEntry = service.fetchOpenTimeEntry()
        #expect(openEntry == nil)
    }

    // MARK: - fetchOpenTimeEntry

    @Test func fetchOpenTimeEntryReturnsNilWhenNone() throws {
        let (service, _) = try makeService()

        let result = service.fetchOpenTimeEntry()

        #expect(result == nil)
    }

    @Test func fetchOpenTimeEntryReturnsOpenEntry() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)
        try context.save()

        service.createTimeEntry(startDate: Date(), for: task.id)

        let result = service.fetchOpenTimeEntry()

        #expect(result != nil)
        #expect(result?.taskId == task.id)
        #expect(result?.entry.endDate == nil)
    }

    // MARK: - trackedTimeToday(for:)

    @Test func trackedTimeTodayForTask() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)

        let now = Date()
        let entry = TimeEntry(task: task, startDate: now.addingTimeInterval(-1800), endDate: now)
        context.insert(entry)
        task.timeEntries = [entry]
        try context.save()

        let time = service.trackedTimeToday(for: task.id)
        #expect(time >= 1799 && time <= 1801)
    }

    @Test func trackedTimeTodayForNonExistentTaskReturnsZero() throws {
        let (service, _) = try makeService()

        let time = service.trackedTimeToday(for: UUID())
        #expect(time == 0)
    }

    // MARK: - fetchTask

    @Test func fetchTaskReturnsItem() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "My Task")
        context.insert(task)
        try context.save()

        let item = service.fetchTask(id: task.id)

        #expect(item != nil)
        #expect(item?.title == "My Task")
    }

    @Test func fetchTaskReturnsNilForNonExistent() throws {
        let (service, _) = try makeService()

        let item = service.fetchTask(id: UUID())

        #expect(item == nil)
    }

    // MARK: - deleteTimeEntry

    @Test func deleteTimeEntryRemovesIt() throws {
        let (service, context) = try makeService()
        let task = TrackerTask(title: "Task")
        context.insert(task)
        try context.save()

        let entry = service.createTimeEntry(startDate: Date(), for: task.id)!
        service.deleteTimeEntry(id: entry.id)

        let openEntry = service.fetchOpenTimeEntry()
        #expect(openEntry == nil)
    }
}
