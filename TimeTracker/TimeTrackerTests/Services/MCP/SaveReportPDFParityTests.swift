import Testing
import Foundation
import MCP
@testable import TimeTracker

/// Pins `save_report_pdf`'s document to the one the Report screen exports.
///
/// The whole promise of this tool is that a file produced unattended is the same file the
/// user would have produced by hand, so this compares the `ReportPDFConfig` the tool hands
/// to the PDF service against the config `ReportViewModel.exportPDF()` builds — the value
/// that fully determines the rendered page. Per architecture decision #10, comparing bytes
/// is not an option: CoreGraphics stamps a creation timestamp, so the same input never
/// renders identical bytes.
@MainActor
struct SaveReportPDFParityTests {

    // MARK: - Fixtures

    /// `Calendar.current`, because `ReportViewModel` uses it and takes no injection.
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

    private func task(title: String, hourlyRate: Double? = nil, entries: [TimeEntryItem]) -> TaskItem {
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

    /// Same shape as `ReportBreakdownParityTests`: one task with its own rate, two on the
    /// default, a zero-time task that both sides must drop, sub-second dust on every entry,
    /// and multiple days per task so the PDF's day rows are worth comparing.
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

    /// What `ReportViewModel.exportPDF()` hands to the PDF service once the save panel has
    /// returned — the same four lines, minus the panel, which cannot run in a test.
    /// `selectedTasks()` is private, so the ticked rows are re-derived here the way it does.
    private func manualExportConfig(
        viewModel: ReportViewModel,
        tasks: [TaskItem],
        preferences: MockUserPreferencesService,
        generatedDate: Date
    ) -> ReportPDFConfig {
        let builder = DefaultReportBuilderService()
        let selectedIds = Set(viewModel.taskRows.filter(\.isSelected).map(\.id))
        let selected = tasks.filter { selectedIds.contains($0.id) }

        return builder.makePDFConfig(
            for: builder.buildReport(
                ReportRequest(
                    tasks: selected,
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate,
                    includeZeroTime: true,
                    preferences: preferences
                )
            ),
            presentation: ReportPresentation(
                businessName: viewModel.businessName,
                currencySymbol: viewModel.currencySymbol,
                generatedDate: generatedDate
            )
        )
    }

    /// The config the tool actually renders, captured off the shared PDF service.
    private func toolConfig(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService,
        generatedDate: Date
    ) async throws -> ReportPDFConfig {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks

        let pdfService = MockReportPDFService()
        let fileWriter = MockMCPFileWriter()
        fileWriter.stubbedDirectories = ["/Users/test/Desktop"]

        let dateProvider = MockDateProvider()
        dateProvider.currentDate = generatedDate

        let tool = SaveReportPDFTool(
            dataStore: store,
            preferences: preferences,
            pdfService: pdfService,
            fileWriter: fileWriter,
            calendar: calendar,
            dateProvider: dateProvider
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
            "destination_path": .string("/Users/test/Desktop"),
        ])
        #expect(result.isError == false)

        return try #require(pdfService.generatePDFLastConfig)
    }

    // MARK: - Parity

    /// `generatedDate` is passed in identically to both sides: it is the one field that is
    /// legitimately "now" on each, and the only thing keeping the two configs from being
    /// comparable field for field.
    private func assertAgreement(rounding: String) async throws {
        let preferences = makePreferences(rounding: rounding)
        let fixtures = tasks
        let generatedDate = date(2026, 2, 1, 9)

        let viewModel = makeViewModel(tasks: fixtures, preferences: preferences)
        let manual = manualExportConfig(
            viewModel: viewModel,
            tasks: fixtures,
            preferences: preferences,
            generatedDate: generatedDate
        )
        let tool = try await toolConfig(
            tasks: fixtures,
            preferences: preferences,
            generatedDate: generatedDate
        )

        // Header.
        #expect(tool.businessName == manual.businessName)
        #expect(tool.currencySymbol == manual.currencySymbol)
        #expect(tool.startDate == manual.startDate)
        #expect(tool.endDate == manual.endDate)
        #expect(tool.generatedDate == manual.generatedDate)

        // Every printed row, in order — this is the body of the document.
        #expect(tool.tasks.isEmpty == false)
        #expect(tool.tasks.count == manual.tasks.count)
        #expect(tool.tasks.map(\.formattedDate) == manual.tasks.map(\.formattedDate))
        #expect(tool.tasks.map(\.title) == manual.tasks.map(\.title))
        #expect(tool.tasks.map(\.formattedTime) == manual.tasks.map(\.formattedTime))
        #expect(tool.tasks.map(\.formattedAmount) == manual.tasks.map(\.formattedAmount))

        // Footer.
        #expect(tool.showAmountColumn == manual.showAmountColumn)
        #expect(tool.totalTime == manual.totalTime)
        #expect(tool.totalAmount == manual.totalAmount)
        #expect(tool.totalRate == manual.totalRate)
    }

    @Test func theSavedPDFMatchesAManualExportWithoutRounding() async throws {
        try await assertAgreement(rounding: "none")
    }

    /// The case that would cost money if the two drifted.
    @Test func theSavedPDFMatchesAManualExportWithFifteenMinuteRounding() async throws {
        try await assertAgreement(rounding: "15")
    }

    @Test func theSavedPDFMatchesAManualExportWithThirtyMinuteRounding() async throws {
        try await assertAgreement(rounding: "30")
    }

    /// The footer the tool renders is the number the screen shows with every row ticked.
    @Test func theSavedPDFsTotalIsTheScreensTotal() async throws {
        let preferences = makePreferences(rounding: "15")
        let fixtures = tasks
        let viewModel = makeViewModel(tasks: fixtures, preferences: preferences)
        let config = try await toolConfig(
            tasks: fixtures,
            preferences: preferences,
            generatedDate: date(2026, 2, 1, 9)
        )

        #expect(config.totalTime == viewModel.totalSelectedTime.formattedHoursMinutes)
        let screenAmount = try #require(viewModel.totalSelectedAmount)
        #expect(config.totalAmount == viewModel.formatCurrency(screenAmount))
        #expect(config.showAmountColumn == viewModel.showAmountColumn)
    }

    /// Both sides drop the zero-time task, so the row comparison above is not agreeing by
    /// coincidence — and rounding must actually be moving the numbers.
    @Test func theFixtureExercisesRoundingAndZeroTimeExclusion() async throws {
        let fixtures = tasks
        let generatedDate = date(2026, 2, 1, 9)

        let unrounded = try await toolConfig(
            tasks: fixtures,
            preferences: makePreferences(rounding: "none"),
            generatedDate: generatedDate
        )
        let rounded = try await toolConfig(
            tasks: fixtures,
            preferences: makePreferences(rounding: "15"),
            generatedDate: generatedDate
        )

        #expect(unrounded.totalTime != rounded.totalTime)
        #expect(unrounded.totalAmount != rounded.totalAmount)
        #expect(fixtures.count == 4)
        #expect(Set(unrounded.tasks.map(\.title)) == ["Acme redesign", "Invoicing", "Bookkeeping"])
    }
}
