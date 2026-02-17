import Foundation

protocol LocalStorageService {
    func fetchTasks() -> [TaskItem]
    func fetchTags() -> [TagItem]
    @discardableResult
    func createTask(title: String, description: String, tagIds: [UUID]) -> TaskItem
    func deleteTask(id: UUID)
    func totalTrackedTimeToday() -> TimeInterval
}
