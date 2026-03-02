import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TrackerTaskTests {

    // MARK: - totalTrackedTime

    @Test func totalTrackedTimeWithNoEntries() {
        let task = TaskEntity(title: "Test")
        #expect(task.totalTrackedTime == 0)
    }

    @Test func totalTrackedTimeWithSingleEntry() {
        let task = TaskEntity(title: "Test")
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600)
        let entry = TimeEntryEntity(task: task, startDate: start, endDate: end)
        task.timeEntries = [entry]

        #expect(task.totalTrackedTime == 3600)
    }

    @Test func totalTrackedTimeWithMultipleEntries() {
        let task = TaskEntity(title: "Test")
        let entry1 = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3600)
        )
        let entry2 = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 7200),
            endDate: Date(timeIntervalSince1970: 9000)
        )
        task.timeEntries = [entry1, entry2]

        #expect(task.totalTrackedTime == 5400) // 3600 + 1800
    }

    // MARK: - trackedTime(from:to:)

    @Test func trackedTimeEntryFullyWithinRange() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200)
        )
        task.timeEntries = [entry]

        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 0),
            to: Date(timeIntervalSince1970: 300)
        )
        #expect(result == 100)
    }

    @Test func trackedTimeEntryPartiallyOverlapsStart() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 50),
            endDate: Date(timeIntervalSince1970: 200)
        )
        task.timeEntries = [entry]

        // Query range starts at 100, entry starts at 50
        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 100),
            to: Date(timeIntervalSince1970: 300)
        )
        #expect(result == 100) // 200 - 100
    }

    @Test func trackedTimeEntryPartiallyOverlapsEnd() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 300)
        )
        task.timeEntries = [entry]

        // Query range ends at 200, entry ends at 300
        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 0),
            to: Date(timeIntervalSince1970: 200)
        )
        #expect(result == 100) // 200 - 100
    }

    @Test func trackedTimeEntrySpansEntireRange() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 500)
        )
        task.timeEntries = [entry]

        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 100),
            to: Date(timeIntervalSince1970: 200)
        )
        #expect(result == 100) // clamped to range
    }

    @Test func trackedTimeEntryOutsideRange() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 500),
            endDate: Date(timeIntervalSince1970: 600)
        )
        task.timeEntries = [entry]

        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 0),
            to: Date(timeIntervalSince1970: 100)
        )
        #expect(result == 0)
    }

    @Test func trackedTimeNoEntries() {
        let task = TaskEntity(title: "Test")

        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 0),
            to: Date(timeIntervalSince1970: 100)
        )
        #expect(result == 0)
    }

    @Test func trackedTimeMultipleOverlappingEntries() {
        let task = TaskEntity(title: "Test")
        let entry1 = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 150)
        )
        let entry2 = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 200),
            endDate: Date(timeIntervalSince1970: 400)
        )
        task.timeEntries = [entry1, entry2]

        // Range 100-300: entry1 contributes 50 (100-150), entry2 contributes 100 (200-300)
        let result = task.trackedTime(
            from: Date(timeIntervalSince1970: 100),
            to: Date(timeIntervalSince1970: 300)
        )
        #expect(result == 150)
    }

    // MARK: - activeTimeEntry

    @Test func activeTimeEntryWithNoEntries() {
        let task = TaskEntity(title: "Test")
        #expect(task.activeTimeEntry == nil)
    }

    @Test func activeTimeEntryAllCompleted() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 100)
        )
        task.timeEntries = [entry]

        #expect(task.activeTimeEntry == nil)
    }

    @Test func activeTimeEntryReturnsOpenEntry() {
        let task = TaskEntity(title: "Test")
        let closedEntry = TimeEntryEntity(
            task: task,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 100)
        )
        let openEntry = TimeEntryEntity(task: task, startDate: Date())
        task.timeEntries = [closedEntry, openEntry]

        #expect(task.activeTimeEntry === openEntry)
    }

    // MARK: - init

    @Test func initSetsDefaults() {
        let task = TaskEntity(title: "My Task", taskDescription: "Desc")

        #expect(task.title == "My Task")
        #expect(task.taskDescription == "Desc")
        #expect(task.isArchived == false)
        #expect(task.hourlyRate == nil)
        #expect(task.tags.isEmpty)
        #expect(task.timeEntries.isEmpty)
    }
}
