import Foundation

@Observable
@MainActor
final class MainWindowViewModel {
    private let localStorageService: LocalStorageService
    private let timerService: TimerService

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

    var timerState: TimerState {
        timerService.state
    }

    var currentTimerTaskId: UUID? {
        timerService.currentTaskId
    }

    var liveTotalToday: TimeInterval {
        if timerService.state == .running {
            return totalToday + timerService.sessionElapsed
        }
        return totalToday
    }

    init(localStorageService: LocalStorageService, timerService: TimerService) {
        self.localStorageService = localStorageService
        self.timerService = timerService
    }

    func loadData() {
        tasks = localStorageService.fetchTasks()
        tags = localStorageService.fetchTags()
        totalToday = localStorageService.totalTrackedTimeToday()
    }

    func deleteTask(id: UUID) {
        if timerService.state == .running && timerService.currentTaskId == id {
            timerService.saveAndStop()
        }
        localStorageService.deleteTask(id: id)
        loadData()
    }

    func startTimer(for task: TaskItem) {
        timerService.startTimer(for: task)
        loadData()
    }

    func pauseTimer() {
        timerService.pauseTimer()
        loadData()
    }
}
