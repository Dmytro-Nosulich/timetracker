import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TimeEntryItemTests {

    @Test func durationWithEndDate() {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 4600)
        let entry = TimeEntryItem(
            id: UUID(),
            startDate: start,
            endDate: end,
            isManual: false,
            note: nil
        )

        #expect(entry.duration == 3600)
    }

    @Test func durationWithNilEndDateUsesCurrentTime() {
        let start = Date(timeIntervalSinceNow: -120)
        let entry = TimeEntryItem(
            id: UUID(),
            startDate: start,
            endDate: nil,
            isManual: false,
            note: nil
        )

        #expect(entry.duration >= 119 && entry.duration <= 121)
    }

    @Test func durationWithSameStartAndEndIsZero() {
        let date = Date()
        let entry = TimeEntryItem(
            id: UUID(),
            startDate: date,
            endDate: date,
            isManual: false,
            note: nil
        )

        #expect(entry.duration == 0)
    }
}
