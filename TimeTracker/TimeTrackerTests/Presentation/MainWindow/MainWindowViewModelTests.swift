import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct MainWindowViewModelTests {

    private func makeMock() -> MockLocalStorageService {
        MockLocalStorageService()
    }

    private func makeTag(name: String = "Tag") -> TagItem {
        TagItem(id: UUID(), name: name, colorHex: "FF0000", createdAt: Date())
    }

    private func makeTask(title: String = "Task", tags: [TagItem] = []) -> TaskItem {
        TaskItem(
            id: UUID(),
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
        let vm = MainWindowViewModel(localStorageService: mock)
        vm.loadData()

        #expect(vm.filteredTasks.count == 2)
    }

    @Test func filteredTasksWithTagFilter() {
        let mock = makeMock()
        let tag = makeTag(name: "Work")
        let task1 = makeTask(title: "Has tag", tags: [tag])
        let task2 = makeTask(title: "No tag", tags: [])
        mock.stubbedTasks = [task1, task2]
        let vm = MainWindowViewModel(localStorageService: mock)
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
        let vm = MainWindowViewModel(localStorageService: mock)
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

        let vm = MainWindowViewModel(localStorageService: mock)
        vm.loadData()

        #expect(vm.tasks.count == 1)
        #expect(vm.tags.count == 1)
        #expect(vm.totalToday == 3600)
        #expect(mock.fetchTasksCallCount == 1)
        #expect(mock.fetchTagsCallCount == 1)
        #expect(mock.totalTrackedTimeTodayCallCount == 1)
    }

    // MARK: - deleteTask

    @Test func deleteTaskCallsServiceAndReloads() {
        let mock = makeMock()
        let taskId = UUID()
        let vm = MainWindowViewModel(localStorageService: mock)
        vm.deleteTask(id: taskId)

        #expect(mock.deleteTaskCallCount == 1)
        #expect(mock.deleteTaskLastId == taskId)
        // loadData is called after delete
        #expect(mock.fetchTasksCallCount == 1)
    }

    // MARK: - init

    @Test func initDefaultState() {
        let mock = makeMock()
        let vm = MainWindowViewModel(localStorageService: mock)

        #expect(vm.tasks.isEmpty)
        #expect(vm.tags.isEmpty)
        #expect(vm.selectedTagFilter == nil)
        #expect(vm.totalToday == 0)
        #expect(vm.showingAddTask == false)
    }
}
