import Foundation

@Observable
@MainActor
final class TimerWindowViewModel {
    private let localStorageService: LocalStorageService
    private let timerService: TimerService

    var tasks: [TaskItem] = []

    var state: TimerState {
        timerService.state
    }

    var sessionElapsed: TimeInterval {
        if timerService.state == .pausedByUser {
            return 0
        }
        return timerService.sessionElapsed
    }

    var currentTaskId: UUID? {
        timerService.currentTaskId
    }

    var currentTask: TaskItem? {
        tasks.first { $0.id == currentTaskId }
    }

    var todayThisTask: TimeInterval {
        guard let taskId = currentTaskId else { return 0 }
        let persisted = localStorageService.trackedTimeToday(for: taskId)
        return persisted
    }

    var todayAllTasks: TimeInterval {
        let persisted = localStorageService.totalTrackedTimeToday()
        return persisted
    }

    init(localStorageService: LocalStorageService, timerService: TimerService) {
        self.localStorageService = localStorageService
        self.timerService = timerService
    }

    func loadTasks() {
        tasks = localStorageService.fetchTasks()
    }

    func togglePauseResume() {
        if state == .running {
            timerService.pauseTimer()
        } else {
            timerService.resumeTimer()
        }
        loadTasks()
    }

    func switchTask(to taskId: UUID) {
        guard taskId != currentTaskId,
              let task = tasks.first(where: { $0.id == taskId }) else { return }
        timerService.startTimer(for: task)
        loadTasks()
    }
}
