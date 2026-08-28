import Foundation
@testable import TimeTracker

/// `MCPDataReading` is async, so `MockLocalStorageService` can't stand in for it.
/// Conventions follow that mock: `stubbed<X>` inputs, `<method>CallCount` tracking.
final class MockMCPDataStore: MCPDataReading, @unchecked Sendable {
    var stubbedTasks: [TaskItem] = []
    var stubbedTags: [TagItem] = []

    private(set) var fetchTasksCallCount = 0
    private(set) var fetchTagsCallCount = 0

    func fetchTasks() async -> [TaskItem] {
        fetchTasksCallCount += 1
        return stubbedTasks
    }

    func fetchTags() async -> [TagItem] {
        fetchTagsCallCount += 1
        return stubbedTags
    }
}
