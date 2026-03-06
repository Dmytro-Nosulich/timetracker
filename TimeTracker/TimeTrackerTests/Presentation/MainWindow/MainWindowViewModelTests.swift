import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct MainWindowViewModelTests {

    private func makeMock() -> MockLocalStorageService {
        MockLocalStorageService()
    }

    private func makeTimerMock() -> MockTimerService {
        MockTimerService()
    }

    private func makeTag(name: String = "Tag") -> TagItem {
        TagItem(id: UUID(), name: name, colorHex: "FF0000", createdAt: Date())
    }

    private func makeTask(id: UUID = UUID(), title: String = "Task", tags: [TagItem] = []) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: tags,
            timeEntries: [],
            totalTrackedTime: 0,
            trackedTimeToday: 0
        )
    }

    // MARK: - filteredTasks

    @Test func filteredTasksNoFilter() {
        let mock = makeMock()
        let tasks = [makeTask(title: "A"), makeTask(title: "B")]
        mock.stubbedTasks = tasks
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadData()

        #expect(vm.filteredTasks.count == 2)
    }

    @Test func filteredTasksWithTagFilter() {
        let mock = makeMock()
        let tag = makeTag(name: "Work")
        let task1 = makeTask(title: "Has tag", tags: [tag])
        let task2 = makeTask(title: "No tag", tags: [])
        mock.stubbedTasks = [task1, task2]
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadData()
        vm.selectedTagFilter = tag

        #expect(vm.filteredTasks.count == 1)
        #expect(vm.filteredTasks.first?.title == "Has tag")
    }

    @Test func filteredTasksWithFilterNoMatch() {
        let mock = makeMock()
        let tag = makeTag(name: "Work")
        let otherTag = makeTag(name: "Personal")
        let task = makeTask(title: "Task", tags: [otherTag])
        mock.stubbedTasks = [task]
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadData()
        vm.selectedTagFilter = tag

        #expect(vm.filteredTasks.isEmpty)
    }

    // MARK: - loadData

    @Test func loadDataPopulatesAllProperties() {
        let mock = makeMock()
        let tag = makeTag()
        let task = makeTask()
        mock.stubbedTasks = [task]
        mock.stubbedTags = [tag]
        mock.stubbedTotalToday = 3600

        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadData()

        #expect(vm.tasks.count == 1)
        #expect(vm.tags.count == 1)
        #expect(vm.totalToday == 3600)
        #expect(mock.fetchTasksCallCount == 1)
        #expect(mock.fetchTagsCallCount == 1)
        #expect(mock.totalTrackedTimeTodayCallCount == 1)
    }

    @Test func loadDataPopulatesTotalThisWeek() {
        let mock = makeMock()
        mock.stubbedTotalThisWeek = 7200
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.loadData()
        #expect(vm.totalThisWeek == 7200)
        #expect(mock.totalTrackedTimeThisWeekCallCount == 1)
    }

    // MARK: - deleteTask

    @Test func deleteTaskCallsServiceAndReloads() {
        let mock = makeMock()
        let taskId = UUID()
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())
        vm.deleteTask(id: taskId)

        #expect(mock.deleteTaskCallCount == 1)
        #expect(mock.deleteTaskLastId == taskId)
        // loadData is called after delete
        #expect(mock.fetchTasksCallCount == 1)
    }

    @Test func deleteTaskStopsTimerIfRunningForThatTask() {
        let mock = makeMock()
        let timerMock = makeTimerMock()
        let taskId = UUID()
        timerMock.stubbedState = .running
        timerMock.stubbedCurrentTaskId = taskId

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.deleteTask(id: taskId)

        #expect(timerMock.saveAndStopCallCount == 1)
        #expect(mock.deleteTaskCallCount == 1)
    }

    @Test func deleteTaskStopsTimerIfPausedByUserForThatTask() {
        let mock = makeMock()
        let timerMock = makeTimerMock()
        let taskId = UUID()
        timerMock.stubbedState = .pausedByUser
        timerMock.stubbedCurrentTaskId = taskId

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.deleteTask(id: taskId)

        #expect(timerMock.saveAndStopCallCount == 1)
        #expect(mock.deleteTaskCallCount == 1)
    }

    @Test func deleteTaskStopsTimerIfPausedByInactivityForThatTask() {
        let mock = makeMock()
        let timerMock = makeTimerMock()
        let taskId = UUID()
        timerMock.stubbedState = .pausedByInactivity
        timerMock.stubbedCurrentTaskId = taskId

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.deleteTask(id: taskId)

        #expect(timerMock.saveAndStopCallCount == 1)
        #expect(mock.deleteTaskCallCount == 1)
    }

    @Test func deleteTaskDoesNotStopTimerIfPausedForDifferentTask() {
        let mock = makeMock()
        let timerMock = makeTimerMock()
        let activeTaskId = UUID()
        let deletedTaskId = UUID()
        timerMock.stubbedState = .pausedByUser
        timerMock.stubbedCurrentTaskId = activeTaskId

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.deleteTask(id: deletedTaskId)

        #expect(timerMock.saveAndStopCallCount == 0)
        #expect(mock.deleteTaskCallCount == 1)
    }

    // MARK: - init

    @Test func initDefaultState() {
        let mock = makeMock()
        let vm = MainWindowViewModel(localStorageService: mock, timerService: makeTimerMock())

        #expect(vm.tasks.isEmpty)
        #expect(vm.tags.isEmpty)
        #expect(vm.selectedTagFilter == nil)
        #expect(vm.totalToday == 0)
        #expect(vm.showingAddTask == false)
    }

    // MARK: - Timer Integration

    @Test func startTimerCallsService() {
        let timerMock = makeTimerMock()
        let task = makeTask()
        let vm = MainWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        vm.startTimer(for: task)

        #expect(timerMock.startTimerCallCount == 1)
        #expect(timerMock.startTimerLastTask == task)
    }

    @Test func pauseTimerCallsService() {
        let timerMock = makeTimerMock()
        let vm = MainWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        vm.pauseTimer()

        #expect(timerMock.pauseTimerCallCount == 1)
    }

    @Test func timerStateReflectsService() {
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running
        let taskId = UUID()
        timerMock.stubbedCurrentTaskId = taskId

        let vm = MainWindowViewModel(localStorageService: makeMock(), timerService: timerMock)

        #expect(vm.timerState == .running)
        #expect(vm.currentTimerTaskId == taskId)
    }

    @Test func liveTotalTodayDoesNotAddSessionElapsedWhenRunning() {
        let mock = makeMock()
        mock.stubbedTotalToday = 3600
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .running
        timerMock.stubbedSessionElapsed = 300

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.loadData()

        #expect(vm.liveTotalToday == 3600)
    }

    @Test func liveTotalTodayDoesNotAddSessionElapsedWhenIdle() {
        let mock = makeMock()
        mock.stubbedTotalToday = 3600
        let timerMock = makeTimerMock()
        timerMock.stubbedState = .idle
        timerMock.stubbedSessionElapsed = 300

        let vm = MainWindowViewModel(localStorageService: mock, timerService: timerMock)
        vm.loadData()

        #expect(vm.liveTotalToday == 3600)
    }
}
