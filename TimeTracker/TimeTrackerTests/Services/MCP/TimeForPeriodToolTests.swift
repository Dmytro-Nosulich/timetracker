import Testing
import Foundation
import MCP
@testable import TimeTracker

struct TimeForPeriodToolTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Wednesday 18 February 2026, 12:00 — so "this week" runs Mon 16th to Sun 22nd.
    private var now: Date { date(2026, 2, 18, 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
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

    private func task(
        id: UUID = UUID(),
        title: String = "Task",
        isArchived: Bool = false,
        entries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: isArchived,
            hourlyRate: nil,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    private func makeTool(tasks: [TaskItem]) -> TimeForPeriodTool {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        let dateProvider = MockDateProvider()
        dateProvider.currentDate = now
        return TimeForPeriodTool(dataStore: store, calendar: calendar, dateProvider: dateProvider)
    }

    private func call(
        _ tool: TimeForPeriodTool,
        period: String?,
        breakdown: String? = nil,
        includeZeroTime: Bool? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> CallTool.Result {
        var arguments: [String: Value] = [:]
        if let period { arguments["period"] = .string(period) }
        if let breakdown { arguments["breakdown"] = .string(breakdown) }
        if let includeZeroTime { arguments["include_zero_time"] = .bool(includeZeroTime) }
        if let startDate { arguments["start_date"] = .string(startDate) }
        if let endDate { arguments["end_date"] = .string(endDate) }
        return await tool.run(arguments: arguments)
    }

    private func payload(
        tasks: [TaskItem],
        period: String?,
        breakdown: String? = nil,
        includeZeroTime: Bool? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> [String: Any] {
        let result = await call(
            makeTool(tasks: tasks),
            period: period,
            breakdown: breakdown,
            includeZeroTime: includeZeroTime,
            startDate: startDate,
            endDate: endDate
        )
        #expect(result.isError == false)
        return try decode(try #require(text(from: result)))
    }

    private func decode(_ json: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [String: Any])
    }

    private func text(from result: CallTool.Result) -> String? {
        for content in result.content {
            if case .text(let text, _, _) = content { return text }
        }
        return nil
    }

    /// Two tasks with time this month: 5h and 2h, plus one with none.
    private var monthlyTasks: [TaskItem] {
        [
            task(title: "Design", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11))]),
            task(
                title: "Invoicing",
                entries: [
                    entry(start: date(2026, 2, 3, 9), end: date(2026, 2, 3, 12)),
                    entry(start: date(2026, 2, 17, 9), end: date(2026, 2, 17, 11)),
                    entry(start: date(2025, 11, 4, 9), end: date(2025, 11, 4, 17)),
                ]
            ),
            task(title: "Idle"),
        ]
    }

    // MARK: - Total-only breakdown

    @Test func theDefaultBreakdownIsASingleTotal() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["breakdown"] as? String == "total")
        #expect(root["totalTrackedTimeSeconds"] as? Int == 7 * 3600)
        #expect(root["totalTrackedTimeFormatted"] as? String == "7h 00m")
        #expect(root["tasks"] == nil)
        #expect(root["taskCount"] == nil)
    }

    @Test func theTotalCoversTheRequestedPeriodAndNothingElse() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "all_time")

        // The November entry only counts once the period stops being February.
        #expect(root["totalTrackedTimeSeconds"] as? Int == 15 * 3600)
    }

    @Test func theResponseEchoesTheResolvedRange() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["period"] as? String == "this_month")
        #expect(root["startDate"] as? String == "2026-02-01")
        #expect(root["endDate"] as? String == "2026-02-28")
    }

    // MARK: - Per-task breakdown

    @Test func perTaskListsEveryTaskWithItsOwnTotal() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month", breakdown: "per_task")

        #expect(root["breakdown"] as? String == "per_task")
        let tasks = try #require(root["tasks"] as? [[String: Any]])
        #expect(tasks.map { $0["title"] as? String } == ["Invoicing", "Design"])
        #expect(tasks.map { $0["trackedTimeSeconds"] as? Int } == [5 * 3600, 2 * 3600])
        #expect(root["taskCount"] as? Int == 2)
    }

    @Test func perTaskStillCarriesThePeriodTotalSoNothingNeedsAddingUp() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month", breakdown: "per_task")

        #expect(root["totalTrackedTimeSeconds"] as? Int == 7 * 3600)
        #expect(root["totalTrackedTimeFormatted"] as? String == "7h 00m")
    }

    @Test func theRowsAlwaysAddUpToTheReportedTotal() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month", breakdown: "per_task")

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        let sum = tasks.compactMap { $0["trackedTimeSeconds"] as? Int }.reduce(0, +)
        #expect(sum == root["totalTrackedTimeSeconds"] as? Int)
    }

    @Test func bothBreakdownsAgreeOnTheTotal() async throws {
        let total = try await payload(tasks: monthlyTasks, period: "this_month")
        let perTask = try await payload(tasks: monthlyTasks, period: "this_month", breakdown: "per_task")

        #expect(total["totalTrackedTimeSeconds"] as? Int == perTask["totalTrackedTimeSeconds"] as? Int)
    }

    @Test func zeroTimeTasksAreLeftOutByDefault() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month", breakdown: "per_task")

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        let titles = tasks.compactMap { $0["title"] as? String }
        #expect(titles == ["Invoicing", "Design"])
    }

    @Test func zeroTimeTasksCanBeAskedFor() async throws {
        let root = try await payload(
            tasks: monthlyTasks,
            period: "this_month",
            breakdown: "per_task",
            includeZeroTime: true
        )

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        #expect(tasks.count == 3)
        #expect(tasks.last?["title"] as? String == "Idle")
        #expect(tasks.last?["trackedTimeSeconds"] as? Int == 0)
        // Listing them changes no total.
        #expect(root["totalTrackedTimeSeconds"] as? Int == 7 * 3600)
    }

    @Test func archivedTasksCountAndAreFlagged() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Retired",
                    isArchived: true,
                    entries: [entry(start: date(2026, 2, 5, 9), end: date(2026, 2, 5, 13))]
                )
            ],
            period: "this_month",
            breakdown: "per_task"
        )

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        #expect(tasks.count == 1)
        #expect(tasks[0]["isArchived"] as? Bool == true)
        #expect(root["totalTrackedTimeSeconds"] as? Int == 4 * 3600)
    }

    @Test func eachRowCarriesItsTaskId() async throws {
        let id = UUID()
        let root = try await payload(
            tasks: [task(id: id, title: "Design", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11))])],
            period: "this_month",
            breakdown: "per_task"
        )

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        #expect(tasks[0]["id"] as? String == id.uuidString)
    }

    @Test func anUnrecognisedBreakdownFallsBackToTheTotalRatherThanErroring() async throws {
        let result = await call(makeTool(tasks: monthlyTasks), period: "this_month", breakdown: "nonsense")

        #expect(result.isError == false)
        let root = try decode(try #require(text(from: result)))
        #expect(root["breakdown"] as? String == "total")
        #expect(root["tasks"] == nil)
    }

    // MARK: - Periods

    @Test func todayCoversOnlyTodaysEntries() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Invoicing",
                    entries: [
                        entry(start: date(2026, 2, 18, 9), end: date(2026, 2, 18, 11)),  // today
                        entry(start: date(2026, 2, 17, 9), end: date(2026, 2, 17, 17)),  // yesterday
                    ]
                )
            ],
            period: "today"
        )

        #expect(root["period"] as? String == "today")
        #expect(root["startDate"] as? String == "2026-02-18")
        #expect(root["totalTrackedTimeSeconds"] as? Int == 2 * 3600)
    }

    @Test func todayCountsARunningEntryUpToNow() async throws {
        let root = try await payload(
            tasks: [task(title: "Invoicing", entries: [entry(start: date(2026, 2, 18, 9), end: nil)])],
            period: "today"
        )

        // now is 12:00.
        #expect(root["totalTrackedTimeSeconds"] as? Int == 3 * 3600)
    }

    @Test func thisWeekRunsMondayToSunday() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Invoicing",
                    entries: [
                        entry(start: date(2026, 2, 16, 9), end: date(2026, 2, 16, 11)),  // Mon, in
                        entry(start: date(2026, 2, 18, 9), end: date(2026, 2, 18, 10)),  // Wed, in
                        entry(start: date(2026, 2, 15, 9), end: date(2026, 2, 15, 17)),  // Sun before, out
                    ]
                )
            ],
            period: "this_week"
        )

        #expect(root["startDate"] as? String == "2026-02-16")
        #expect(root["endDate"] as? String == "2026-02-22")
        #expect(root["totalTrackedTimeSeconds"] as? Int == 3 * 3600)
    }

    @Test func aCustomRangeIsHonouredInclusivelyAtBothEnds() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Invoicing",
                    entries: [
                        entry(start: date(2026, 2, 2, 9), end: date(2026, 2, 2, 11)),  // first day
                        entry(start: date(2026, 2, 4, 22), end: date(2026, 2, 4, 23)),  // last day, late
                        entry(start: date(2026, 2, 5, 9), end: date(2026, 2, 5, 17)),  // just outside
                    ]
                )
            ],
            period: "custom",
            startDate: "2026-02-02",
            endDate: "2026-02-04"
        )

        #expect(root["totalTrackedTimeSeconds"] as? Int == 3 * 3600)
        #expect(root["startDate"] as? String == "2026-02-02")
        #expect(root["endDate"] as? String == "2026-02-04")
    }

    @Test func allTimeReportsNoRangeBounds() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "all_time")

        #expect(root["period"] as? String == "all_time")
        #expect(root["startDate"] == nil)
        #expect(root["endDate"] == nil)
    }

    @Test func aMissingPeriodIsAnErrorTheCallerCanFix() async throws {
        let result = await call(makeTool(tasks: monthlyTasks), period: nil)

        #expect(result.isError == true)
        #expect(text(from: result)?.contains("\"this_month\"") == true)
    }

    @Test func aCustomRangeWithoutDatesIsAnErrorTheCallerCanFix() async throws {
        let result = await call(makeTool(tasks: monthlyTasks), period: "custom")

        #expect(result.isError == true)
        #expect(text(from: result)?.contains("start_date") == true)
    }

    // MARK: - Tool definition

    @Test func definitionRequiresThePeriod() throws {
        guard case .object(let schema) = TimeForPeriodTool.definition.inputSchema,
              case .array(let required)? = schema["required"]
        else {
            Issue.record("Unexpected input schema shape")
            return
        }

        #expect(required == [.string("period")])
    }

    @Test func definitionAdvertisesEveryPeriodAndBothBreakdowns() throws {
        guard case .object(let schema) = TimeForPeriodTool.definition.inputSchema,
              case .object(let properties)? = schema["properties"],
              case .object(let period)? = properties["period"],
              case .array(let periods)? = period["enum"],
              case .object(let breakdown)? = properties["breakdown"],
              case .array(let breakdowns)? = breakdown["enum"]
        else {
            Issue.record("Unexpected input schema shape")
            return
        }

        #expect(periods.count == ReportPeriod.allCases.count)
        #expect(periods.contains(.string("today")))
        #expect(periods.contains(.string("this_week")))
        #expect(breakdowns == [.string("total"), .string("per_task")])
    }

    @Test func definitionIsMarkedReadOnly() {
        #expect(TimeForPeriodTool.definition.annotations.readOnlyHint == true)
        #expect(TimeForPeriodTool.definition.annotations.openWorldHint == false)
    }

    @Test func definitionPointsAtTheOtherToolSoTheTwoDontGetConfused() {
        #expect(TimeForPeriodTool.definition.description?.contains(TimeForTaskTool.name) == true)
    }
}
