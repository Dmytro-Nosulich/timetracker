import Testing
import Foundation
@testable import TimeTracker

struct TimeEntryOverlapTests {

    private func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 17
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test func nonOverlappingRangesReturnFalse() {
        let existing: [(id: UUID, start: Date, end: Date)] = [
            (UUID(), date(hour: 9), date(hour: 11)),
            (UUID(), date(hour: 14), date(hour: 16)),
        ]
        let result = hasOverlappingTimeRanges(
            existing: existing,
            newStart: date(hour: 11, minute: 30),
            newEnd: date(hour: 13)
        )
        #expect(result == false)
    }

    @Test func overlappingRangesReturnTrue() {
        let existing: [(id: UUID, start: Date, end: Date)] = [
            (UUID(), date(hour: 9), date(hour: 12)),
        ]
        let result = hasOverlappingTimeRanges(
            existing: existing,
            newStart: date(hour: 11),
            newEnd: date(hour: 13)
        )
        #expect(result == true)
    }

    @Test func adjacentRangesDoNotOverlap() {
        let existing: [(id: UUID, start: Date, end: Date)] = [
            (UUID(), date(hour: 9), date(hour: 11)),
        ]
        let result = hasOverlappingTimeRanges(
            existing: existing,
            newStart: date(hour: 11),
            newEnd: date(hour: 13)
        )
        #expect(result == false)
    }

    @Test func excludingIdSkipsThatEntry() {
        let idToExclude = UUID()
        let existing: [(id: UUID, start: Date, end: Date)] = [
            (idToExclude, date(hour: 9), date(hour: 12)),
        ]
        let result = hasOverlappingTimeRanges(
            existing: existing,
            newStart: date(hour: 10),
            newEnd: date(hour: 11),
            excludingId: idToExclude
        )
        #expect(result == false)
    }

    @Test func excludingIdStillChecksOtherEntries() {
        let idToExclude = UUID()
        let otherId = UUID()
        let existing: [(id: UUID, start: Date, end: Date)] = [
            (idToExclude, date(hour: 9), date(hour: 10)),
            (otherId, date(hour: 11), date(hour: 13)),
        ]
        let result = hasOverlappingTimeRanges(
            existing: existing,
            newStart: date(hour: 12),
            newEnd: date(hour: 14),
            excludingId: idToExclude
        )
        #expect(result == true)
    }

    @Test func emptyExistingReturnsFalse() {
        let result = hasOverlappingTimeRanges(
            existing: [],
            newStart: date(hour: 9),
            newEnd: date(hour: 11)
        )
        #expect(result == false)
    }
}
