import Testing
import Foundation
@testable import TimeTracker

struct MCPPeriodArgumentTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func entry(start: Date, end: Date?) -> TimeEntryItem {
        TimeEntryItem(id: UUID(), startDate: start, endDate: end, isManual: false, note: nil)
    }

    private func task(entries: [TimeEntryItem] = []) -> TaskItem {
        TaskItem(
            id: UUID(),
            title: "Task",
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    /// Wednesday 18 February 2026, matching `ReportPeriodTests`' anchor.
    private var now: Date { date(2026, 2, 18) }

    private func resolve(
        period: String?,
        startDate: String? = nil,
        endDate: String? = nil,
        fallback: ReportPeriod? = nil
    ) -> Result<MCPPeriodArgument.Resolved, MCPPeriodArgument.Failure> {
        MCPPeriodArgument.resolve(
            period: period,
            startDate: startDate,
            endDate: endDate,
            fallback: fallback,
            calendar: calendar,
            now: now
        )
    }

    private func resolved(
        period: String?,
        startDate: String? = nil,
        endDate: String? = nil,
        fallback: ReportPeriod? = nil
    ) throws -> MCPPeriodArgument.Resolved {
        try resolve(period: period, startDate: startDate, endDate: endDate, fallback: fallback).get()
    }

    private func failure(
        period: String?,
        startDate: String? = nil,
        endDate: String? = nil,
        fallback: ReportPeriod? = nil
    ) -> MCPPeriodArgument.Failure? {
        switch resolve(period: period, startDate: startDate, endDate: endDate, fallback: fallback) {
        case .failure(let failure): failure
        case .success: nil
        }
    }

    // MARK: - Named periods

    @Test func everyAdvertisedNameResolvesToItsReportPeriod() throws {
        let expected: [(String, ReportPeriod)] = [
            ("today", .today),
            ("this_week", .thisWeek),
            ("last_week", .lastWeek),
            ("this_month", .thisMonth),
            ("last_month", .lastMonth),
            ("this_year", .thisYear),
            ("all_time", .allTime),
            ("custom", .customRange),
        ]

        for (name, period) in expected {
            #expect(MCPPeriodArgument.period(named: name) == period)
        }
    }

    @Test func everyReportPeriodCaseIsAdvertised() {
        #expect(Set(MCPPeriodArgument.orderedPeriods) == Set(ReportPeriod.allCases))
        #expect(MCPPeriodArgument.names.count == ReportPeriod.allCases.count)
    }

    @Test func nameMatchingToleratesSpacingAndCasing() {
        #expect(MCPPeriodArgument.period(named: "this month") == .thisMonth)
        #expect(MCPPeriodArgument.period(named: "thisMonth") == .thisMonth)
        #expect(MCPPeriodArgument.period(named: "This Month") == .thisMonth)
        #expect(MCPPeriodArgument.period(named: "LAST-WEEK") == .lastWeek)
        #expect(MCPPeriodArgument.period(named: "customRange") == .customRange)
    }

    @Test func namedPeriodsUseReportPeriodsOwnDateRange() throws {
        let period = try resolved(period: "this_month")
        let expected = ReportPeriod.thisMonth.dateRange(calendar: calendar, now: now)

        #expect(period.start == expected.start)
        #expect(period.end == expected.end)
        #expect(period.period == .thisMonth)
        #expect(period.name == "this_month")
    }

    @Test func aMissingPeriodUsesTheFallbackWhenThereIsOne() throws {
        #expect(try resolved(period: nil, fallback: .allTime).period == .allTime)
        #expect(try resolved(period: "", fallback: .allTime).period == .allTime)
        #expect(try resolved(period: "   ", fallback: .allTime).period == .allTime)
    }

    @Test func aMissingPeriodFailsWhenThereIsNoFallback() {
        #expect(failure(period: nil) == .missingPeriod)
    }

    @Test func anUnknownPeriodFails() {
        #expect(failure(period: "last_fortnight") == .unknownPeriod("last_fortnight"))
    }

    // MARK: - Custom ranges

    @Test func customRangeCoversBothDatesInclusively() throws {
        let period = try resolved(period: "custom", startDate: "2026-02-02", endDate: "2026-02-04")

        #expect(period.start == date(2026, 2, 2, 0))
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: period.end)
        #expect(endComponents.day == 4)
        #expect(endComponents.hour == 23)
        #expect(endComponents.minute == 59)
        #expect(endComponents.second == 59)
    }

    @Test func aSingleDayCustomRangeIsValid() throws {
        let period = try resolved(period: "custom", startDate: "2026-02-02", endDate: "2026-02-02")

        #expect(period.start == date(2026, 2, 2, 0))
        #expect(period.end > period.start)
    }

    @Test func customRangeNeedsBothDates() {
        #expect(failure(period: "custom", startDate: "2026-02-02") == .missingCustomDates)
        #expect(failure(period: "custom", endDate: "2026-02-04") == .missingCustomDates)
        #expect(failure(period: "custom") == .missingCustomDates)
    }

    @Test func anUnreadableDateFails() {
        #expect(
            failure(period: "custom", startDate: "02/02/2026", endDate: "2026-02-04")
                == .unparsableDate("02/02/2026")
        )
    }

    @Test func aFullTimestampIsAcceptedRatherThanRejected() throws {
        let period = try resolved(
            period: "custom",
            startDate: "2026-02-02T09:30:00Z",
            endDate: "2026-02-04T17:00:00Z"
        )

        // Still snapped to whole days at both ends.
        #expect(period.start == date(2026, 2, 2, 0))
        #expect(calendar.dateComponents([.hour], from: period.end).hour == 23)
    }

    @Test func anInvertedRangeFails() {
        #expect(failure(period: "custom", startDate: "2026-02-04", endDate: "2026-02-02") == .invertedRange)
    }

    @Test func startAndEndDatesAreIgnoredForNamedPeriods() throws {
        let period = try resolved(period: "this_month", startDate: "1999-01-01", endDate: "1999-12-31")
        let expected = ReportPeriod.thisMonth.dateRange(calendar: calendar, now: now)

        #expect(period.start == expected.start)
        #expect(period.end == expected.end)
    }

    // MARK: - Failure messages

    @Test func everyFailureMessageSaysWhatToDoInstead() {
        let failures: [MCPPeriodArgument.Failure] = [
            .missingPeriod,
            .unknownPeriod("nonsense"),
            .missingCustomDates,
            .unparsableDate("nonsense"),
            .invertedRange,
        ]

        for failure in failures {
            #expect(!failure.message.isEmpty)
        }
        #expect(MCPPeriodArgument.Failure.missingPeriod.message.contains("\"this_month\""))
        #expect(MCPPeriodArgument.Failure.unknownPeriod("x").message.contains("\"all_time\""))
        #expect(MCPPeriodArgument.Failure.missingCustomDates.message.contains("YYYY-MM-DD"))
    }

    // MARK: - Tracked time

    @Test func trackedTimeClipsEntriesToTheRange() throws {
        let period = try resolved(period: "custom", startDate: "2026-02-02", endDate: "2026-02-02")
        // 22:00 on the 2nd to 02:00 on the 3rd — only the part before midnight is inside.
        let subject = task(entries: [entry(start: date(2026, 2, 2, 22), end: date(2026, 2, 3, 2))])

        // One second short of two hours: every ReportPeriod case ends its range at
        // 23:59:59, and custom ranges follow the same convention rather than inventing a
        // second end-of-day rule that would disagree with the Report screen.
        #expect(period.trackedTime(for: subject) == 2 * 3600 - 1)
    }

    @Test func trackedTimeIsZeroForAnEntryOutsideTheRange() throws {
        let period = try resolved(period: "custom", startDate: "2026-02-02", endDate: "2026-02-02")
        let subject = task(entries: [entry(start: date(2026, 1, 5, 9), end: date(2026, 1, 5, 17))])

        #expect(period.trackedTime(for: subject) == 0)
    }

    @Test func allTimeReportsTheTasksOwnTotalRatherThanAggregatingARange() throws {
        let period = try resolved(period: "all_time")
        // Dated after `now`, so any range ending today would miss it — the all-time total
        // must still count it, exactly as list_tasks_and_tags reports it.
        let subject = task(entries: [entry(start: date(2026, 3, 1, 9), end: date(2026, 3, 1, 12))])

        #expect(period.trackedTime(for: subject) == subject.totalTrackedTime)
        #expect(period.trackedTime(for: subject) == 3 * 3600)
    }

    @Test func aRunningEntryCountsUpToNow() throws {
        let period = try resolved(period: "today")
        let subject = task(entries: [entry(start: date(2026, 2, 18, 9), end: nil)])

        // now is 12:00, so three hours so far.
        #expect(period.trackedTime(for: subject) == 3 * 3600)
    }

    // MARK: - Response bounds

    @Test func boundsAreFormattedAsPlainDates() throws {
        let period = try resolved(period: "custom", startDate: "2026-02-02", endDate: "2026-02-04")
        let bounds = try #require(period.formattedBounds)

        #expect(bounds.start == "2026-02-02")
        #expect(bounds.end == "2026-02-04")
    }

    @Test func allTimeHasNoBoundsToReport() throws {
        #expect(try resolved(period: "all_time").formattedBounds == nil)
    }
}
