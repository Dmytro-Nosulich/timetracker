import Testing
import Foundation
@testable import TimeTracker

struct ReportPeriodTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = TimeZone.current
        return cal
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)!
    }

    // MARK: - This Week

    @Test func thisWeekStartsOnMondayEndsOnSunday() {
        // Wednesday Feb 18, 2026
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.thisWeek.dateRange(calendar: calendar, now: now)
        let startComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.year == 2026)
        #expect(startComponents.month == 2)
        #expect(startComponents.day == 16) // Monday
        #expect(endComponents.day == 22) // Sunday
    }

    // MARK: - Last Week

    @Test func lastWeekIsPreviousMonToSun() {
        let now = date(year: 2026, month: 2, day: 18) // Wed
        let range = ReportPeriod.lastWeek.dateRange(calendar: calendar, now: now)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.month == 2)
        #expect(startComponents.day == 9)
        #expect(endComponents.day == 15)
    }

    // MARK: - This Month

    @Test func thisMonthCoversFullMonth() {
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.thisMonth.dateRange(calendar: calendar, now: now)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.month == 2)
        #expect(startComponents.day == 1)
        #expect(endComponents.month == 2)
        #expect(endComponents.day == 28)
    }

    // MARK: - Last Month

    @Test func lastMonthCoversPreviousMonth() {
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.lastMonth.dateRange(calendar: calendar, now: now)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)
        #expect(endComponents.month == 1)
        #expect(endComponents.day == 31)
    }

    // MARK: - This Year

    @Test func thisYearCoversJanToDec() {
        let now = date(year: 2026, month: 6, day: 15)
        let range = ReportPeriod.thisYear.dateRange(calendar: calendar, now: now)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.year == 2026)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)
        #expect(endComponents.year == 2026)
        #expect(endComponents.month == 12)
        #expect(endComponents.day == 31)
    }

    // MARK: - All Time

    @Test func allTimeStartsAtDistantPast() {
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.allTime.dateRange(calendar: calendar, now: now)
        #expect(range.start == Date.distantPast)
        #expect(range.end > now || calendar.isDate(range.end, inSameDayAs: now))
    }

    // MARK: - Default filename

    @Test func thisMonthFilename() {
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.thisMonth.dateRange(calendar: calendar, now: now)
        let filename = ReportPeriod.thisMonth.defaultFilename(startDate: range.start, endDate: range.end)
        #expect(filename.contains("February 2026"))
    }

    @Test func allTimeFilename() {
        let now = date(year: 2026, month: 2, day: 18)
        let range = ReportPeriod.allTime.dateRange(calendar: calendar, now: now)
        let filename = ReportPeriod.allTime.defaultFilename(startDate: range.start, endDate: range.end)
        #expect(filename == "Time Report - All Time")
    }

    // MARK: - CaseIterable

    @Test func allCasesContainsSevenOptions() {
        #expect(ReportPeriod.allCases.count == 7)
    }
}
