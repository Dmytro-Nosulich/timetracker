import Foundation
@testable import TimeTracker

final class MockLocalStorageService: LocalStorageService {
    // MARK: - Stub Data

    var stubbedTasks: [TaskItem] = []
    var stubbedTags: [TagItem] = []
    var stubbedTotalToday: TimeInterval = 0
    var stubbedCreatedTask: TaskItem?

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
}
