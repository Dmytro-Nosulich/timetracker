import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TimerWindowViewModelTests {

    private func makeMock() -> MockLocalStorageService {
        MockLocalStorageService()
    }

    private func makeTimerMock() -> MockTimerService {
        MockTimerService()
    }

    private func makeTask(id: UUID = UUID(), title: String = "Task") -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: [],
            totalTrackedTime: 0,
            trackedTimeToday: 0
        )
    }

    // MARK: - loadTasks

    @Test func loadTasksFetchesFromStorage() {
        let mock = makeMock()
        let tasks = [makeTask(title: "A"), makeTask(title: "B")]
        mock.stubbedTasks = tasks

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadTasks()

        #expect(vm.tasks.count == 2)
        #expect(mock.fetchTasksCallCount == 1)
    }

    // MARK: - togglePauseResume

    @Test func togglePauseResumeWhenRunningCallsPause() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)
        vm.togglePauseResume()

        #expect(timerMock.pauseTimerCallCount == 1)
        #expect(timerMock.resumeTimerCallCount == 0)
    }

    @Test func togglePauseResumeWhenPausedCallsResume() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .pausedByUser

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)
        vm.togglePauseResume()

        #expect(timerMock.resumeTimerCallCount == 1)
        #expect(timerMock.pauseTimerCallCount == 0)
    }

    @Test func togglePauseResumeWhenIdleCallsResume() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .idle

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)
        vm.togglePauseResume()

        #expect(timerMock.resumeTimerCallCount == 1)
    }

    // MARK: - switchTask

    @Test func switchTaskCallsStartTimerWithCorrectTask() {
        let timerMock = makeTimerMock()
        let task1 = makeTask(title: "Task 1")
        let task2 = makeTask(title: "Task 2")
        timerMock.stubbedCurrentTaskId = task1.id

        let mock = makeMock()
        mock.stubbedTasks = [task1, task2]

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.loadTasks()
        vm.switchTask(to: task2.id)

        #expect(timerMock.startTimerCallCount == 1)
        #expect(timerMock.startTimerLastTask == task2)
    }

    @Test func switchTaskToSameTaskIsNoOp() {
        let timerMock = makeTimerMock()
        let task = makeTask()
        timerMock.stubbedCurrentTaskId = task.id

        let mock = makeMock()
        mock.stubbedTasks = [task]

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.loadTasks()
        vm.switchTask(to: task.id)

        #expect(timerMock.startTimerCallCount == 0)
    }

    // MARK: - Computed Properties

    @Test func sessionElapsedShowsZeroWhenPausedByUser() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .pausedByUser
        timerMock.stubbedSessionElapsed = 300

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        #expect(vm.sessionElapsed == 0)
    }

    @Test func sessionElapsedShowsValueWhenRunning() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running
        timerMock.stubbedSessionElapsed = 300

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        #expect(vm.sessionElapsed == 300)
    }

    @Test func todayThisTaskIncludesSessionElapsedWhenRunning() {
        let mock = makeMock()
        mock.stubbedTrackedTimeTodayForTask = 3600
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running
        timerMock.stubbedSessionElapsed = 300
        let taskId = UUID()
        timerMock.stubbedCurrentTaskId = taskId

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)

        #expect(vm.todayThisTask == 3900)
    }

    @Test func todayAllTasksIncludesSessionElapsedWhenRunning() {
        let mock = makeMock()
        mock.stubbedTotalToday = 7200
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running
        timerMock.stubbedSessionElapsed = 600

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)

        #expect(vm.todayAllTasks == 7800)
    }

    @Test func todayAllTasksDoesNotAddElapsedWhenPaused() {
        let mock = makeMock()
        mock.stubbedTotalToday = 7200
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .pausedByUser
        timerMock.stubbedSessionElapsed = 600

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)

        #expect(vm.todayAllTasks == 7200)
    }

    @Test func currentTaskReturnsMatchingTask() {
        let timerMock = makeTimerMock()
        let task = makeTask()
        timerMock.stubbedCurrentTaskId = task.id

        let mock = makeMock()
        mock.stubbedTasks = [task]

        let vm = TimerWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.loadTasks()

        #expect(vm.currentTask == task)
    }

    @Test func stateReflectsTimerService() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .pausedByInactivity

        let vm = TimerWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        #expect(vm.state == .pausedByInactivity)
    }
}
