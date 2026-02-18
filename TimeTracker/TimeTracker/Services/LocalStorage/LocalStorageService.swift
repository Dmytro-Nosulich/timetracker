import Foundation

protocol LocalStorageService {
    func fetchTasks() -> [TaskItem]
    func fetchTags() -> [TagItem]
    @discardableResult
    func createTask(title: String, description: String, tagIds: [UUID]) -> TaskItem
    func deleteTask(id: UUID)
    func totalTrackedTimeToday() -> TimeInterval

    // MARK: - Time Entry Operations

    @discardableResult
    func createTimeEntry(startDate: Date, for taskId: UUID) -> TimeEntryItem?
    func closeTimeEntry(id: UUID, endDate: Date)
    func fetchOpenTimeEntry() -> (entry: TimeEntryItem, taskId: UUID)?
    func trackedTimeToday(for taskId: UUID) -> TimeInterval
    func fetchTask(id: UUID) -> TaskItem?
    func deleteTimeEntry(id: UUID)
}
