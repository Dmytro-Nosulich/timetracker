import Foundation
import Combine

@Observable
@MainActor
final class MainWindowViewModel {
    private let localStorageService: LocalStorageService
    private let timerService: TimerService
    private var cancellables = Set<AnyCancellable>()

    var tasks: [TaskItem] = []
    var tags: [TagItem] = []
    var selectedTagFilter: TagItem?
    var searchText: String = ""
    var totalToday: TimeInterval = 0
    var totalThisWeek: TimeInterval = 0
    var showingAddTask = false

    var filteredTasks: [TaskItem] {
        var result = tasks
        if let tag = selectedTagFilter {
            result = result.filter { task in
                task.tags.contains(where: { $0.id == tag.id })
            }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { task in
                task.title.localizedCaseInsensitiveContains(query)
                    || task.taskDescription.localizedCaseInsensitiveContains(query)
            }
        }
        return result
    }

    var timerState: TimerState {
        timerService.state
    }

    var currentTimerTaskId: UUID? {
        timerService.currentTaskId
    }

    var liveTotalToday: TimeInterval {
        totalToday
    }

    init(localStorageService: LocalStorageService, timerService: TimerService) {
        self.localStorageService = localStorageService
        self.timerService = timerService

        NotificationCenter.default
            .publisher(for: .timerDisplayDidUpdate)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadData()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .taskDetailDidSave)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadData()
                }
            }
            .store(in: &cancellables)
    }

    func loadData() {
        tasks = localStorageService.fetchTasks()
        tags = localStorageService.fetchTags()
        totalToday = localStorageService.totalTrackedTimeToday()
        totalThisWeek = localStorageService.totalTrackedTimeThisWeek()
    }

    func deleteTask(id: UUID) {
        let isActiveTask = timerService.currentTaskId == id
        let isActiveState = timerService.state == .running
            || timerService.state == .pausedByUser
            || timerService.state == .pausedByInactivity
        if isActiveTask && isActiveState {
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
