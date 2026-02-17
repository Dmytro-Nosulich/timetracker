import Foundation

@Observable
@MainActor
final class MainWindowViewModel {
    private let localStorageService: LocalStorageService

    var tasks: [TaskItem] = []
    var tags: [TagItem] = []
    var selectedTagFilter: TagItem?
    var totalToday: TimeInterval = 0
    var showingAddTask = false

    var filteredTasks: [TaskItem] {
        guard let tag = selectedTagFilter else { return tasks }
        return tasks.filter { task in
            task.tags.contains(where: { $0.id == tag.id })
        }
    }

    init(localStorageService: LocalStorageService) {
        self.localStorageService = localStorageService
    }

    func loadData() {
        tasks = localStorageService.fetchTasks()
        tags = localStorageService.fetchTags()
        totalToday = localStorageService.totalTrackedTimeToday()
    }

    func deleteTask(id: UUID) {
        localStorageService.deleteTask(id: id)
        loadData()
    }
}
