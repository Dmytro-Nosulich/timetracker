import Testing
import Foundation
import MCP
@testable import TimeTracker

/// Pins `get_billable_report` to the Report screen.
///
/// Both sides are driven from one set of tasks and one `MockUserPreferencesService`, so any
/// divergence in rounding, rate resolution, ordering or currency formatting fails here. A
/// mismatch between what the AI reports and what the user's invoice says is a billing bug,
/// which is why this is asserted rather than assumed from shared code.
@MainActor
struct ReportBreakdownParityTests {

    // MARK: - Fixtures

    /// `Calendar.current`, because `ReportViewModel` uses it and takes no injection —
    /// aligning the tool with it is what makes the comparison meaningful.
    private var calendar: Calendar { .current }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func entry(start: Date, end: Date, extraSeconds: TimeInterval = 0) -> TimeEntryItem {
        TimeEntryItem(
            id: UUID(),
            startDate: start,
            endDate: end.addingTimeInterval(extraSeconds),
            isManual: false,
            note: nil
        )
    }

    private func task(
        title: String,
        hourlyRate: Double? = nil,
        entries: [TimeEntryItem]
    ) -> TaskItem {
        TaskItem(
            id: UUID(),
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

    /// Deliberately mixed: a task with its own rate, two falling back to the default, and
    /// awkward durations so rounding actually changes the numbers — 6h05m, 3h10m and 25m
    /// round in different directions and by different amounts, so they cannot cancel out
    /// (`theFixtureIsSensitiveToRounding` guards exactly that). Raw totals are distinct, so
    /// row order is unambiguous. Entries sit at midday on ordinary days: no DST or
    /// midnight-crossing edge case is in play here — those are covered by
    /// `DefaultReportBuilderServiceTests`.
    ///
    /// Every entry carries a **sub-second fraction**, because real entries do. That is what
    /// makes this a real parity check: truncating each row separately and truncating the
    /// sum give different integers, so the tool has to derive its totals the same way the
    /// screen does rather than by re-adding its own rows.
    private var tasks: [TaskItem] {
        [
            task(title: "Acme redesign", hourlyRate: 80, entries: [
                entry(start: date(2026, 1, 6, 10), end: date(2026, 1, 6, 12, 10), extraSeconds: 0.7),
                entry(start: date(2026, 1, 8, 13), end: date(2026, 1, 8, 16, 55), extraSeconds: 0.6),
            ]),
            task(title: "Invoicing", entries: [
                entry(start: date(2026, 1, 20, 9), end: date(2026, 1, 20, 9, 25), extraSeconds: 0.8),
            ]),
            task(title: "Bookkeeping", entries: [
                entry(start: date(2026, 1, 12, 14), end: date(2026, 1, 12, 17, 10), extraSeconds: 0.9),
            ]),
            task(title: "Never touched", entries: []),
        ]
    }

    private var rangeStart: Date { calendar.startOfDay(for: date(2026, 1, 5, 0)) }
    private var rangeEnd: Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date(2026, 1, 30, 12))!
    }

    private func makePreferences(rounding: String) -> MockUserPreferencesService {
        let preferences = MockUserPreferencesService()
        preferences.stubbedTimeRounding = rounding
        preferences.stubbedDefaultHourlyRate = 50
        preferences.stubbedCurrencySymbol = "$"
        preferences.stubbedBusinessName = "Acme Ltd"
        return preferences
    }

    /// The Report screen, showing the fixture range. `onAppear()` resets the dates from the
    /// selected period, so the custom range has to be applied after it.
    private func makeViewModel(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService
    ) -> ReportViewModel {
        let localStorage = MockLocalStorageService()
        localStorage.stubbedTasks = tasks

        let viewModel = ReportViewModel(
            localStorageService: localStorage,
            userPreferencesService: preferences,
            pdfService: MockReportPDFService(),
            reportBuilder: DefaultReportBuilderService()
        )
        viewModel.onAppear()
        viewModel.selectedPeriod = .customRange
        viewModel.setStartDate(rangeStart)
        viewModel.setEndDate(rangeEnd)
        return viewModel
    }

    private func toolPayload(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService
    ) async throws -> [String: Any] {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        let tool = ReportBreakdownTool(
            dataStore: store,
            preferences: preferences,
            calendar: calendar
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let result = await tool.run(arguments: [
            "period": .string("custom"),
            "start_date": .string(formatter.string(from: rangeStart)),
            "end_date": .string(formatter.string(from: rangeEnd)),
        ])
        #expect(result.isError == false)

        var json: String?
        for content in result.content {
            if case .text(let text, _, _) = content { json = text }
        }
        let object = try JSONSerialization.jsonObject(with: Data(try #require(json).utf8))
        return try #require(object as? [String: Any])
    }

    // MARK: - Parity

    /// Currency strings are compared against the view model's own formatting rather than
    /// pinned literals: the dev machine formats decimals with a comma.
    private func assertAgreement(rounding: String) async throws {
        let preferences = makePreferences(rounding: rounding)
        let fixtures = tasks
        let viewModel = makeViewModel(tasks: fixtures, preferences: preferences)
        let payload = try await toolPayload(tasks: fixtures, preferences: preferences)

        let rows = viewModel.taskRows
        #expect(rows.isEmpty == false)

        let toolTasks = try #require(payload["tasks"] as? [[String: Any]])
        #expect(toolTasks.count == rows.count)
        #expect(payload["taskCount"] as? Int == rows.count)

        // Same tasks, same order.
        #expect(toolTasks.compactMap { $0["id"] as? String } == rows.map { $0.id.uuidString })
        #expect(toolTasks.compactMap { $0["title"] as? String } == rows.map(\.title))

        for (toolTask, row) in zip(toolTasks, rows) {
            #expect(toolTask["roundedTimeSeconds"] as? Int == Int(row.roundedTime))
            #expect(toolTask["roundedTimeFormatted"] as? String == row.roundedTime.formattedHoursMinutes)
            #expect(toolTask["hourlyRate"] as? Double == row.hourlyRate)
            #expect(toolTask["hourlyRateFormatted"] as? String == viewModel.formattedRate(for: row))
            #expect(toolTask["amount"] as? Double == row.amount)
            #expect(toolTask["amountFormatted"] as? String == viewModel.formattedAmount(for: row))
        }

        // Totals, as the screen's footer shows them with every row selected.
        #expect(payload["totalRoundedTimeSeconds"] as? Int == Int(viewModel.totalSelectedTime))
        #expect(
            payload["totalRoundedTimeFormatted"] as? String
                == viewModel.totalSelectedTime.formattedHoursMinutes
        )

        let screenTotalAmount = try #require(viewModel.totalSelectedAmount)
        #expect(payload["totalAmount"] as? Double == screenTotalAmount)
        #expect(
            payload["totalAmountFormatted"] as? String == viewModel.formatCurrency(screenTotalAmount)
        )

        #expect(payload["showAmountColumn"] as? Bool == viewModel.showAmountColumn)
        #expect(payload["currencySymbol"] as? String == viewModel.currencySymbol)
        #expect(payload["businessName"] as? String == viewModel.businessName)
    }

    @Test func theToolMatchesTheReportScreenWithoutRounding() async throws {
        try await assertAgreement(rounding: "none")
    }

    /// The case that would actually cost money if the two drifted.
    @Test func theToolMatchesTheReportScreenWithFifteenMinuteRounding() async throws {
        try await assertAgreement(rounding: "15")
    }

    @Test func theToolMatchesTheReportScreenWithThirtyMinuteRounding() async throws {
        try await assertAgreement(rounding: "30")
    }

    /// The sub-second fractions must actually change the integers, or the parity tests
    /// above would agree trivially and the live 22-task discrepancy that prompted this
    /// fixture would still slip through. With rounding off, truncating each row separately
    /// loses more than truncating the sum once — and the tool has to report the latter,
    /// because that is the number in the Report screen's footer.
    @Test func theFixtureCarriesSubSecondDust() async throws {
        let preferences = makePreferences(rounding: "none")
        let fixtures = tasks
        let viewModel = makeViewModel(tasks: fixtures, preferences: preferences)
        let payload = try await toolPayload(tasks: fixtures, preferences: preferences)

        let rowSum = try #require(payload["tasks"] as? [[String: Any]])
            .compactMap { $0["roundedTimeSeconds"] as? Int }
            .reduce(0, +)

        #expect(rowSum != payload["totalRoundedTimeSeconds"] as? Int)
        #expect(payload["totalRoundedTimeSeconds"] as? Int == Int(viewModel.totalSelectedTime))
    }

    /// Rounding must be doing something, or the tests above would agree trivially.
    @Test func theFixtureIsSensitiveToRounding() async throws {
        let unrounded = try await toolPayload(tasks: tasks, preferences: makePreferences(rounding: "none"))
        let rounded = try await toolPayload(tasks: tasks, preferences: makePreferences(rounding: "15"))

        #expect(
            unrounded["totalRoundedTimeSeconds"] as? Int != rounded["totalRoundedTimeSeconds"] as? Int
        )
        #expect(unrounded["totalAmount"] as? Double != rounded["totalAmount"] as? Double)
    }

    /// The screen hides zero-time tasks by default, and so must the tool — otherwise the
    /// row counts above would agree only by coincidence.
    @Test func bothSidesDropTheZeroTimeTask() async throws {
        let preferences = makePreferences(rounding: "none")
        let fixtures = tasks
        let viewModel = makeViewModel(tasks: fixtures, preferences: preferences)
        let payload = try await toolPayload(tasks: fixtures, preferences: preferences)

        #expect(fixtures.count == 4)
        #expect(viewModel.taskRows.count == 3)
        #expect(payload["taskCount"] as? Int == 3)
    }
}
