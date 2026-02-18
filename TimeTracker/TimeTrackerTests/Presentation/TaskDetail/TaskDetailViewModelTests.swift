import Testing
import Foundation
import SwiftData
@testable import TimeTracker

@MainActor
struct TaskDetailViewModelTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TaskEntity.self, TimeEntryEntity.self, TagEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func initLoadsTaskFromChildContext() throws {
        let container = try makeInMemoryContainer()
        let mainContext = container.mainContext

        let task = TaskEntity(title: "Test Task", taskDescription: "Desc")
        mainContext.insert(task)
        try mainContext.save()

        let coordinator = TaskDetailCoordinator()

        let vm = TaskDetailViewModel(
            taskId: task.id,
            modelContainer: container,
            coordinator: coordinator,
            currencySymbol: "$",
            onClose: { }
        )

        #expect(vm.task != nil)
        #expect(vm.title == "Test Task")
        #expect(vm.taskDescription == "Desc")
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test func editingTitleSetsHasUnsavedChanges() throws {
        let container = try makeInMemoryContainer()
        let mainContext = container.mainContext

        let task = TaskEntity(title: "Original", taskDescription: "")
        mainContext.insert(task)
        try mainContext.save()

        let coordinator = TaskDetailCoordinator()
        let vm = TaskDetailViewModel(
            taskId: task.id,
            modelContainer: container,
            coordinator: coordinator,
            currencySymbol: "$",
            onClose: {}
        )

        vm.title = "Modified"

        #expect(vm.hasUnsavedChanges == true)
        #expect(coordinator.hasUnsavedChanges == true)
    }

    @Test func entriesForDayFiltersByDate() throws {
        let container = try makeInMemoryContainer()
        let mainContext = container.mainContext

        let task = TaskEntity(title: "Task", taskDescription: "")
        mainContext.insert(task)

        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 17
        components.hour = 9
        components.minute = 0
        let dayStart = Calendar.current.date(from: components)!
        let dayEnd = Calendar.current.date(byAdding: .hour, value: 2, to: dayStart)!

        let entry = TimeEntryEntity(task: task, startDate: dayStart, endDate: dayEnd, isManual: false)
        mainContext.insert(entry)
        task.timeEntries.append(entry)
        try mainContext.save()

        let coordinator = TaskDetailCoordinator()
        let vm = TaskDetailViewModel(
            taskId: task.id,
            modelContainer: container,
            coordinator: coordinator,
            currencySymbol: "$",
            onClose: {}
        )

        vm.selectedDate = dayStart
        let entries = vm.entriesForDay(dayStart)
        #expect(entries.count == 1)
        #expect(entries.first?.id == entry.id)

        let otherDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let entriesOtherDay = vm.entriesForDay(otherDay)
        #expect(entriesOtherDay.isEmpty)
    }

    @Test func hoursForDaySumsCorrectly() throws {
        let container = try makeInMemoryContainer()
        let mainContext = container.mainContext

        let task = TaskEntity(title: "Task", taskDescription: "")
        mainContext.insert(task)

        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 17
        components.hour = 9
        components.minute = 0
        let dayStart = Calendar.current.date(from: components)!
        let entry1End = Calendar.current.date(byAdding: .hour, value: 1, to: dayStart)!
        let entry2Start = Calendar.current.date(byAdding: .hour, value: 2, to: dayStart)!
        let entry2End = Calendar.current.date(byAdding: .hour, value: 3, to: dayStart)!

        let e1 = TimeEntryEntity(task: task, startDate: dayStart, endDate: entry1End, isManual: false)
        let e2 = TimeEntryEntity(task: task, startDate: entry2Start, endDate: entry2End, isManual: false)
        mainContext.insert(e1)
        mainContext.insert(e2)
        task.timeEntries.append(contentsOf: [e1, e2])
        try mainContext.save()

        let coordinator = TaskDetailCoordinator()
        let vm = TaskDetailViewModel(
            taskId: task.id,
            modelContainer: container,
            coordinator: coordinator,
            currencySymbol: "$",
            onClose: {}
        )

        let hours = vm.hoursForDay(dayStart)
        #expect(hours == 7200)
    }

    @Test func taskNotFoundResultsInNilTask() throws {
        let container = try makeInMemoryContainer()
        let coordinator = TaskDetailCoordinator()

        let vm = TaskDetailViewModel(
            taskId: UUID(),
            modelContainer: container,
            coordinator: coordinator,
            currencySymbol: "$",
            onClose: {}
        )

        #expect(vm.task == nil)
    }
}
