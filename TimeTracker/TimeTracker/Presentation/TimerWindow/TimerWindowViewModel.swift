import Foundation
import Combine

@Observable
@MainActor
final class TimerWindowViewModel {
    private let localStorageService: LocalStorageService
    private let timerService: TimerService
    private let userPreferences: UserPreferencesService
    private var cancellables = Set<AnyCancellable>()

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

    var thisWeekAllTasks: TimeInterval {
        localStorageService.totalTrackedTimeThisWeek()
    }

    var taskReminderEnabled: Bool {
        userPreferences.taskReminderEnabled
    }

    var taskReminderDurationHours: Int {
        Int(userPreferences.taskReminderDuration) / 3600
    }

    var taskReminderDurationMinutes: Int {
        (Int(userPreferences.taskReminderDuration) % 3600) / 60
    }

    var taskReminderMode: TaskReminderMode {
        userPreferences.taskReminderMode
    }

    init(localStorageService: LocalStorageService, timerService: TimerService, userPreferences: UserPreferencesService) {
        self.localStorageService = localStorageService
        self.timerService = timerService
        self.userPreferences = userPreferences

        NotificationCenter.default
            .publisher(for: .taskDetailDidSave)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadTasks()
                }
            }
            .store(in: &cancellables)
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

    func setReminderEnabled(_ enabled: Bool) {
        userPreferences.setTaskReminderEnabled(enabled)
    }

    func setReminderDuration(hours: Int, minutes: Int) {
        let duration = TimeInterval(max(0, hours) * 3600 + max(0, minutes) * 60)
        userPreferences.setTaskReminderDuration(duration)
    }

    func setReminderMode(_ mode: TaskReminderMode) {
        userPreferences.setTaskReminderMode(mode)
    }
}
