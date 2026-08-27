import Testing
import Foundation
import MCP
@testable import TimeTracker

struct ReportBreakdownToolTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Wednesday 18 February 2026, 12:00.
    private var now: Date { date(2026, 2, 18, 12) }

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

    private func task(
        id: UUID = UUID(),
        title: String = "Task",
        hourlyRate: Double? = nil,
        entries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: hourlyRate,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    private func makeTool(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService = MockUserPreferencesService(),
        calendar: Calendar? = nil
    ) -> ReportBreakdownTool {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        let dateProvider = MockDateProvider()
        dateProvider.currentDate = now
        return ReportBreakdownTool(
            dataStore: store,
            preferences: preferences,
            calendar: calendar ?? self.calendar,
            dateProvider: dateProvider
        )
    }

    private func call(
        _ tool: ReportBreakdownTool,
        period: String?,
        includeZeroTime: Bool? = nil,
        includeDailyBreakdown: Bool? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> CallTool.Result {
        var arguments: [String: Value] = [:]
        if let period { arguments["period"] = .string(period) }
        if let includeZeroTime { arguments["include_zero_time"] = .bool(includeZeroTime) }
        if let includeDailyBreakdown {
            arguments["include_daily_breakdown"] = .bool(includeDailyBreakdown)
        }
        if let startDate { arguments["start_date"] = .string(startDate) }
        if let endDate { arguments["end_date"] = .string(endDate) }
        return await tool.run(arguments: arguments)
    }

    private func payload(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService = MockUserPreferencesService(),
        period: String?,
        includeZeroTime: Bool? = nil,
        includeDailyBreakdown: Bool? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> [String: Any] {
        let result = await call(
            makeTool(tasks: tasks, preferences: preferences),
            period: period,
            includeZeroTime: includeZeroTime,
            includeDailyBreakdown: includeDailyBreakdown,
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

    /// Design: 2h10m on the 10th. Invoicing: 3h on the 3rd + 2h on the 17th. Idle: nothing.
    private var monthlyTasks: [TaskItem] {
        [
            task(title: "Design", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11, 10))]),
            task(
                title: "Invoicing",
                entries: [
                    entry(start: date(2026, 2, 3, 9), end: date(2026, 2, 3, 12)),
                    entry(start: date(2026, 2, 17, 9), end: date(2026, 2, 17, 11)),
                ]
            ),
            task(title: "Idle"),
        ]
    }

    private func tasks(in root: [String: Any]) throws -> [[String: Any]] {
        try #require(root["tasks"] as? [[String: Any]])
    }

    // MARK: - Period handling

    @Test func theResponseEchoesTheResolvedRange() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["period"] as? String == "this_month")
        #expect(root["startDate"] as? String == "2026-02-01")
        #expect(root["endDate"] as? String == "2026-02-28")
    }

    @Test func aCustomRangeIsInclusiveAtBothEnds() async throws {
        let root = try await payload(
            tasks: monthlyTasks,
            period: "custom",
            startDate: "2026-02-03",
            endDate: "2026-02-10"
        )

        // The 17th falls outside, so Invoicing keeps only its 3h on the 3rd.
        let rows = try tasks(in: root)
        #expect(rows.map { $0["title"] as? String } == ["Invoicing", "Design"])
        #expect(rows.map { $0["rawTimeSeconds"] as? Int } == [3 * 3600, 2 * 3600 + 600])
    }

    @Test func aMissingPeriodIsACallerError() async throws {
        let result = await call(makeTool(tasks: monthlyTasks), period: nil)

        #expect(result.isError == true)
        let message = try #require(text(from: result))
        #expect(message.contains("this_month"))
    }

    @Test func customWithoutDatesIsACallerError() async throws {
        let result = await call(makeTool(tasks: monthlyTasks), period: "custom")

        #expect(result.isError == true)
        #expect(try #require(text(from: result)).contains("start_date"))
    }

    // MARK: - Rounding

    @Test func roundingIsAppliedAndEchoed() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedTimeRounding = "15"

        let root = try await payload(tasks: monthlyTasks, preferences: preferences, period: "this_month")

        #expect(root["roundingMinutes"] as? Int == 15)
        let rows = try tasks(in: root)
        let design = try #require(rows.first { $0["title"] as? String == "Design" })
        // 2h10m raw rounds up to 2h15m.
        #expect(design["rawTimeSeconds"] as? Int == 2 * 3600 + 600)
        #expect(design["roundedTimeSeconds"] as? Int == 2 * 3600 + 900)
        #expect(design["roundedTimeFormatted"] as? String == "2h 15m")
    }

    @Test func noRoundingReportsZeroMinutesAndLeavesTimeAlone() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["roundingMinutes"] as? Int == 0)
        let design = try #require(try tasks(in: root).first { $0["title"] as? String == "Design" })
        #expect(design["rawTimeSeconds"] as? Int == design["roundedTimeSeconds"] as? Int)
    }

    // MARK: - Rates and amounts

    @Test func theTaskRateWinsOverTheDefaultRate() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedDefaultHourlyRate = 50

        let root = try await payload(
            tasks: [task(title: "Design", hourlyRate: 80, entries: [
                entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11)),
            ])],
            preferences: preferences,
            period: "this_month"
        )

        let design = try #require(try tasks(in: root).first)
        #expect(design["hourlyRate"] as? Double == 80)
        #expect(design["hourlyRateFormatted"] as? String == "$80/h")
        #expect(design["amount"] as? Double == 160)
    }

    @Test func theDefaultRateAppliesWhenATaskHasNone() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedDefaultHourlyRate = 50

        let root = try await payload(tasks: monthlyTasks, preferences: preferences, period: "this_month")

        #expect(root["defaultHourlyRate"] as? Double == 50)
        #expect(root["defaultHourlyRateFormatted"] as? String == "$50/h")
        #expect(root["showAmountColumn"] as? Bool == true)
        let invoicing = try #require(try tasks(in: root).first { $0["title"] as? String == "Invoicing" })
        #expect(invoicing["hourlyRate"] as? Double == 50)
        #expect(invoicing["amount"] as? Double == 250)
    }

    @Test func withNoRateAnywhereEveryAmountIsAbsent() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["showAmountColumn"] as? Bool == false)
        #expect(root["totalAmount"] == nil)
        #expect(root["totalAmountFormatted"] == nil)
        #expect(root["defaultHourlyRate"] == nil)
        for row in try tasks(in: root) {
            #expect(row["amount"] == nil)
            #expect(row["amountFormatted"] == nil)
            #expect(row["hourlyRate"] == nil)
        }
    }

    @Test func amountsUseRoundedTimeNotRawTime() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedDefaultHourlyRate = 60
        preferences.stubbedTimeRounding = "15"

        let root = try await payload(
            tasks: [task(title: "Design", entries: [
                entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11, 10)),
            ])],
            preferences: preferences,
            period: "this_month"
        )

        // 2h15m at $60/h is $135; the raw 2h10m would be $130.
        let design = try #require(try tasks(in: root).first)
        #expect(design["amount"] as? Double == 135)
    }

    @Test func currencyFormattingUsesThePreferredSymbol() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedDefaultHourlyRate = 50
        preferences.stubbedCurrencySymbol = "€"

        let root = try await payload(tasks: monthlyTasks, preferences: preferences, period: "this_month")

        #expect(root["currencySymbol"] as? String == "€")
        let total = try #require(root["totalAmount"] as? Double)
        #expect(root["totalAmountFormatted"] as? String == CurrencyFormatting.amount(total, symbol: "€"))
        let design = try #require(try tasks(in: root).first { $0["title"] as? String == "Design" })
        #expect(design["hourlyRateFormatted"] as? String == "€50/h")
    }

    // MARK: - Totals and ordering

    @Test func rowsAreDescendingByTimeAndSumToTheTotal() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedTimeRounding = "15"

        let root = try await payload(tasks: monthlyTasks, preferences: preferences, period: "this_month")

        let rows = try tasks(in: root)
        #expect(rows.map { $0["title"] as? String } == ["Invoicing", "Design"])
        let sum = rows.compactMap { $0["roundedTimeSeconds"] as? Int }.reduce(0, +)
        #expect(sum == root["totalRoundedTimeSeconds"] as? Int)
        #expect(root["totalRoundedTimeFormatted"] as? String == TimeInterval(sum).formattedHoursMinutes)
    }

    /// Entries rarely land on whole seconds in real data. Each row drops its own sub-second
    /// fraction while the total drops one fraction over the sum, so the rows can come out a
    /// few seconds short — the same truncation the Report screen does per row, kept rather
    /// than "fixed" because the total has to stay the one the screen shows.
    @Test func theTotalIsTheScreensAndNeedNotEqualTheSumOfTruncatedRows() async throws {
        let fractional = (0..<3).map { index in
            task(
                title: "Task \(index)",
                entries: [entry(
                    start: date(2026, 2, 10, 9),
                    end: date(2026, 2, 10, 10).addingTimeInterval(0.8)
                )]
            )
        }

        let root = try await payload(tasks: fractional, period: "this_month")

        let rows = try tasks(in: root)
        // Each row truncates 3600.8 to 3600; the total truncates 10802.4 to 10802.
        #expect(rows.compactMap { $0["roundedTimeSeconds"] as? Int } == [3600, 3600, 3600])
        #expect(root["totalRoundedTimeSeconds"] as? Int == 10802)
        // The note is what stops a caller re-deriving the total from those rows.
        #expect(try #require(root["note"] as? String).contains("Report the totals as given"))
    }

    @Test func theNoteIsAlwaysPresentAndGainsTheDayCaveatOnDemand() async throws {
        let plain = try await payload(tasks: monthlyTasks, period: "this_month")
        let plainNote = try #require(plain["note"] as? String)
        #expect(plainNote.contains("Day rows") == false)

        let withDays = try await payload(
            tasks: monthlyTasks,
            period: "this_month",
            includeDailyBreakdown: true
        )
        #expect(try #require(withDays["note"] as? String).contains("Day rows"))
    }

    @Test func amountsSumToTheTotalAmount() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedDefaultHourlyRate = 50

        let root = try await payload(tasks: monthlyTasks, preferences: preferences, period: "this_month")

        let sum = try tasks(in: root).compactMap { $0["amount"] as? Double }.reduce(0, +)
        #expect(root["totalAmount"] as? Double == sum)
    }

    // MARK: - Zero-time filtering

    @Test func zeroTimeTasksAreLeftOutByDefault() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        #expect(root["taskCount"] as? Int == 2)
        #expect(try tasks(in: root).contains { $0["title"] as? String == "Idle" } == false)
    }

    @Test func zeroTimeTasksCanBeAskedFor() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month", includeZeroTime: true)

        #expect(root["taskCount"] as? Int == 3)
        let idle = try #require(try tasks(in: root).first { $0["title"] as? String == "Idle" })
        #expect(idle["roundedTimeSeconds"] as? Int == 0)
    }

    // MARK: - Daily breakdown

    @Test func theDailyBreakdownIsAbsentByDefault() async throws {
        let root = try await payload(tasks: monthlyTasks, period: "this_month")

        for row in try tasks(in: root) {
            #expect(row["days"] == nil)
        }
    }

    @Test func theDailyBreakdownIsAscendingByDateWhenAskedFor() async throws {
        let root = try await payload(
            tasks: monthlyTasks,
            period: "this_month",
            includeDailyBreakdown: true
        )

        let invoicing = try #require(try tasks(in: root).first { $0["title"] as? String == "Invoicing" })
        let days = try #require(invoicing["days"] as? [[String: Any]])
        #expect(days.map { $0["date"] as? String } == ["2026-02-03", "2026-02-17"])
        #expect(days.map { $0["rawTimeSeconds"] as? Int } == [3 * 3600, 2 * 3600])
        #expect(root["note"] != nil)
    }

    /// Decision #9: day rows are rounded per day while the total rounds each task's whole
    /// period once, so the two legitimately disagree. Pinned here so nobody "fixes" it.
    @Test func dayRowsNeedNotSumToTheTaskTotal() async throws {
        let preferences = MockUserPreferencesService()
        preferences.stubbedTimeRounding = "15"

        let root = try await payload(
            tasks: [task(title: "Design", entries: [
                entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 9, 10)),
                entry(start: date(2026, 2, 11, 9), end: date(2026, 2, 11, 9, 10)),
                entry(start: date(2026, 2, 12, 9), end: date(2026, 2, 12, 9, 10)),
            ])],
            preferences: preferences,
            period: "this_month",
            includeDailyBreakdown: true
        )

        let design = try #require(try tasks(in: root).first)
        let days = try #require(design["days"] as? [[String: Any]])
        // Three 10-minute days round to 15m each, but 30m raw rounds to 30m overall.
        #expect(days.compactMap { $0["roundedTimeSeconds"] as? Int } == [900, 900, 900])
        #expect(design["roundedTimeSeconds"] as? Int == 1800)
    }

    // MARK: - Presentation values

    @Test func theBusinessNameComesFromPreferencesAndIsOmittedWhenBlank() async throws {
        let named = MockUserPreferencesService()
        named.stubbedBusinessName = "Acme Ltd"
        let withName = try await payload(tasks: monthlyTasks, preferences: named, period: "this_month")
        #expect(withName["businessName"] as? String == "Acme Ltd")

        let blank = try await payload(tasks: monthlyTasks, period: "this_month")
        #expect(blank["businessName"] == nil)
    }
}
