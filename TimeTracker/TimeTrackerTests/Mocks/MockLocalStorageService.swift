import Foundation
@testable import TimeTracker

final class MockLocalStorageService: LocalStorageService {
    // MARK: - Stub Data

    var stubbedTasks: [TaskItem] = []
    var stubbedTags: [TagItem] = []
    var stubbedTotalToday: TimeInterval = 0
    var stubbedCreatedTask: TaskItem?
    var stubbedCreatedTimeEntry: TimeEntryItem?
    var stubbedOpenTimeEntry: (entry: TimeEntryItem, taskId: UUID)?
    var stubbedTrackedTimeTodayForTask: TimeInterval = 0
    var stubbedFetchedTask: TaskItem?

    // MARK: - Call Tracking

    var fetchTasksCallCount = 0
    var fetchTagsCallCount = 0
    var createTaskCallCount = 0
    var createTaskLastTitle: String?
    var createTaskLastDescription: String?
    var createTaskLastTagIds: [UUID]?
    var deleteTaskCallCount = 0
    var deleteTaskLastId: UUID?
    var totalTrackedTimeTodayCallCount = 0
    var createTimeEntryCallCount = 0
    var createTimeEntryLastTaskId: UUID?
    var createTimeEntryLastStartDate: Date?
    var closeTimeEntryCallCount = 0
    var closeTimeEntryLastId: UUID?
    var closeTimeEntryLastEndDate: Date?
    var fetchOpenTimeEntryCallCount = 0
    var trackedTimeTodayForTaskCallCount = 0
    var trackedTimeTodayLastTaskId: UUID?
    var fetchTaskCallCount = 0
    var fetchTaskLastId: UUID?
    var deleteTimeEntryCallCount = 0
    var deleteTimeEntryLastId: UUID?

    // MARK: - LocalStorageService

    func fetchTasks() -> [TaskItem] {
        fetchTasksCallCount += 1
        return stubbedTasks
    }

    func fetchTags() -> [TagItem] {
        fetchTagsCallCount += 1
        return stubbedTags
    }

    @discardableResult
    func createTask(title: String, description: String, tagIds: [UUID]) -> TaskItem {
        createTaskCallCount += 1
        createTaskLastTitle = title
        createTaskLastDescription = description
        createTaskLastTagIds = tagIds

        return stubbedCreatedTask ?? TaskItem(
            id: UUID(),
            title: title,
            taskDescription: description,
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: [],
            totalTrackedTime: 0,
            trackedTimeToday: 0
        )
    }

    func deleteTask(id: UUID) {
        deleteTaskCallCount += 1
        deleteTaskLastId = id
    }

    func totalTrackedTimeToday() -> TimeInterval {
        totalTrackedTimeTodayCallCount += 1
        return stubbedTotalToday
    }

    // MARK: - Time Entry Operations

    @discardableResult
    func createTimeEntry(startDate: Date, for taskId: UUID) -> TimeEntryItem? {
        createTimeEntryCallCount += 1
        createTimeEntryLastTaskId = taskId
        createTimeEntryLastStartDate = startDate
        return stubbedCreatedTimeEntry ?? TimeEntryItem(
            id: UUID(), startDate: startDate, endDate: nil, isManual: false, note: nil
        )
    }

    func closeTimeEntry(id: UUID, endDate: Date) {
        closeTimeEntryCallCount += 1
        closeTimeEntryLastId = id
        closeTimeEntryLastEndDate = endDate
    }

    func fetchOpenTimeEntry() -> (entry: TimeEntryItem, taskId: UUID)? {
        fetchOpenTimeEntryCallCount += 1
        return stubbedOpenTimeEntry
    }

    func trackedTimeToday(for taskId: UUID) -> TimeInterval {
        trackedTimeTodayForTaskCallCount += 1
        trackedTimeTodayLastTaskId = taskId
        return stubbedTrackedTimeTodayForTask
    }

    func fetchTask(id: UUID) -> TaskItem? {
        fetchTaskCallCount += 1
        fetchTaskLastId = id
        return stubbedFetchedTask
    }

    func deleteTimeEntry(id: UUID) {
        deleteTimeEntryCallCount += 1
        deleteTimeEntryLastId = id
    }
}
