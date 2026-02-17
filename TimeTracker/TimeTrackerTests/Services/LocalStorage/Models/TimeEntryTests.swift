import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TimeEntryTests {

    @Test func durationWithEndDate() {
        let task = TaskEntity(title: "Test")
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 4600)
        let entry = TimeEntryEntity(task: task, startDate: start, endDate: end)

        #expect(entry.duration == 3600)
    }

    @Test func durationWithNilEndDateUsesCurrentTime() {
        let task = TaskEntity(title: "Test")
        let start = Date(timeIntervalSinceNow: -60)
        let entry = TimeEntryEntity(task: task, startDate: start)

        #expect(entry.duration >= 59 && entry.duration <= 61)
    }

    @Test func initSetsAllProperties() {
        let task = TaskEntity(title: "Test")
        let start = Date()
        let end = Date(timeIntervalSinceNow: 100)
        let entry = TimeEntryEntity(task: task, startDate: start, endDate: end, isManual: true, note: "A note")

        #expect(entry.task === task)
        #expect(entry.startDate == start)
        #expect(entry.endDate == end)
        #expect(entry.isManual == true)
        #expect(entry.note == "A note")
        #expect(entry.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test func initDefaultValues() {
        let task = TaskEntity(title: "Test")
        let entry = TimeEntryEntity(task: task, startDate: Date())

        #expect(entry.endDate == nil)
        #expect(entry.isManual == false)
        #expect(entry.note == nil)
    }
}
