import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct AddTaskViewModelTests {

    private func makeMock(tags: [TagItem] = []) -> MockLocalStorageService {
        let mock = MockLocalStorageService()
        mock.stubbedTags = tags
        return mock
    }

    private func makeTag(name: String = "Tag") -> TagItem {
        TagItem(id: UUID(), name: name, colorHex: "FF0000", createdAt: Date())
    }

    // MARK: - isValid

    @Test func isValidWithEmptyTitle() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        vm.title = ""
        #expect(vm.isValid == false)
    }

    @Test func isValidWithWhitespaceOnlyTitle() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        vm.title = "   \n\t  "
        #expect(vm.isValid == false)
    }

    @Test func isValidWithNonEmptyTitle() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        vm.title = "My Task"
        #expect(vm.isValid == true)
    }

    @Test func isValidWithPaddedTitle() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        vm.title = "  My Task  "
        #expect(vm.isValid == true)
    }

    // MARK: - toggleTag

    @Test func toggleTagAddsWhenNotPresent() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        let tagId = UUID()
        vm.toggleTag(id: tagId)

        #expect(vm.selectedTagIds.contains(tagId))
    }

    @Test func toggleTagRemovesWhenPresent() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        let tagId = UUID()
        vm.selectedTagIds.insert(tagId)
        vm.toggleTag(id: tagId)

        #expect(!vm.selectedTagIds.contains(tagId))
    }

    @Test func toggleTagMultipleTimes() {
        let vm = AddTaskViewModel(localStorageService: makeMock())
        let tagId = UUID()
        vm.toggleTag(id: tagId)
        vm.toggleTag(id: tagId)
        vm.toggleTag(id: tagId)

        #expect(vm.selectedTagIds.contains(tagId))
    }

    // MARK: - createTask

    @Test func createTaskWithInvalidTitleReturnsFalse() {
        let mock = makeMock()
        let vm = AddTaskViewModel(localStorageService: mock)
        vm.title = ""

        let result = vm.createTask()

        #expect(result == false)
        #expect(mock.createTaskCallCount == 0)
    }

    @Test func createTaskWithValidTitleReturnsTrue() {
        let mock = makeMock()
        let vm = AddTaskViewModel(localStorageService: mock)
        vm.title = "New Task"
        vm.taskDescription = "A description"

        let result = vm.createTask()

        #expect(result == true)
        #expect(mock.createTaskCallCount == 1)
        #expect(mock.createTaskLastTitle == "New Task")
        #expect(mock.createTaskLastDescription == "A description")
    }

    @Test func createTaskTrimsTitle() {
        let mock = makeMock()
        let vm = AddTaskViewModel(localStorageService: mock)
        vm.title = "  Padded Title  "

        _ = vm.createTask()

        #expect(mock.createTaskLastTitle == "Padded Title")
    }

    @Test func createTaskPassesSelectedTagIds() {
        let mock = makeMock()
        let vm = AddTaskViewModel(localStorageService: mock)
        vm.title = "Task"
        let tagId1 = UUID()
        let tagId2 = UUID()
        vm.selectedTagIds = [tagId1, tagId2]

        _ = vm.createTask()

        let passedIds = Set(mock.createTaskLastTagIds ?? [])
        #expect(passedIds == [tagId1, tagId2])
    }

    // MARK: - init

    @Test func initFetchesTagsFromService() {
        let tag = makeTag()
        let mock = makeMock(tags: [tag])

        let vm = AddTaskViewModel(localStorageService: mock)

        #expect(vm.availableTags.count == 1)
        #expect(vm.availableTags.first?.name == tag.name)
        #expect(mock.fetchTagsCallCount == 1)
    }

    @Test func initDefaultState() {
        let vm = AddTaskViewModel(localStorageService: makeMock())

        #expect(vm.title == "")
        #expect(vm.taskDescription == "")
        #expect(vm.selectedTagIds.isEmpty)
    }
}
