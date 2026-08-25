import Testing
import Foundation
@testable import TimeTracker

struct DailyTimeAggregatorTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func entry(start: Date, end: Date?) -> TimeEntryItem {
        TimeEntryItem(id: UUID(), startDate: start, endDate: end, isManual: false, note: nil)
    }

    @Test func entryFullyWithinSingleDay() {
        let entries = [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        let expected: TimeInterval = 3 * 3600
        #expect(totals[date(2026, 3, 10)] == expected)
        #expect(totals.count == 1)
    }

    @Test func entrySpanningMidnightSplitsAcrossTwoDays() {
        let entries = [entry(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 1))]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        #expect(totals[date(2026, 3, 10)] == 3600)
        #expect(totals[date(2026, 3, 11)] == 3600)
    }

    @Test func multiDayEntrySplitsAcrossAllDaysSpanned() {
        let entries = [entry(start: date(2026, 3, 10, 22), end: date(2026, 3, 13, 2))]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        let twoHours: TimeInterval = 2 * 3600
        let fullDay: TimeInterval = 24 * 3600
        #expect(totals[date(2026, 3, 10)] == twoHours)
        #expect(totals[date(2026, 3, 11)] == fullDay)
        #expect(totals[date(2026, 3, 12)] == fullDay)
        #expect(totals[date(2026, 3, 13)] == twoHours)
    }

    @Test func entryOutsideRangeIsExcluded() {
        let entries = [entry(start: date(2026, 2, 15, 9), end: date(2026, 2, 15, 12))]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        #expect(totals.isEmpty)
    }

    @Test func entryClippedAtRangeStartBoundary() {
        let entries = [entry(start: date(2026, 2, 28, 22), end: date(2026, 3, 1, 2))]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        let expected: TimeInterval = 2 * 3600
        #expect(totals[date(2026, 2, 28)] == nil)
        #expect(totals[date(2026, 3, 1)] == expected)
    }

    @Test func multipleEntriesOnSameDayAreSummed() {
        let entries = [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10)),
            entry(start: date(2026, 3, 10, 14), end: date(2026, 3, 10, 16)),
        ]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar
        )
        let expected: TimeInterval = 3 * 3600
        #expect(totals[date(2026, 3, 10)] == expected)
    }

    @Test func openEntryUsesProvidedNow() {
        let entries = [entry(start: date(2026, 3, 10, 9), end: nil)]
        let totals = DailyTimeAggregator.dailyTotals(
            for: entries,
            rangeStart: date(2026, 3, 1),
            rangeEnd: date(2026, 4, 1),
            calendar: calendar,
            now: date(2026, 3, 10, 11)
        )
        let expected: TimeInterval = 2 * 3600
        #expect(totals[date(2026, 3, 10)] == expected)
    }
}
