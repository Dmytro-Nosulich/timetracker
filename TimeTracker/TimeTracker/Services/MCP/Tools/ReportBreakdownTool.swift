import Foundation
import MCP

/// MCP tool #3 — the report the user would invoice from: time per task with their rounding
/// setting applied and hourly-rate amounts computed. Read-only; it returns the numbers
/// behind the PDF, not a file.
///
/// The maths is `DefaultReportBuilderService`'s, the same service the Report screen and the
/// PDF export run through, so what this tool reports and what the user's invoice says
/// cannot disagree.
struct ReportBreakdownTool: Sendable {
    static let name = "get_billable_report"

    static let definition = Tool(
        name: name,
        description: """
            The user's time report for a period, per task, exactly as their Report screen \
            and exported PDF show it: their time-rounding setting applied, each task's \
            hourly rate resolved (its own rate, else the default rate), and the amount \
            owed for each. Use this for anything about billing, invoicing, rates, amounts, \
            money earned, rounded or billable hours, or "the report" for a period — \
            including when no hourly rate is configured, since the rounding still applies. \
            Report the amounts as given; they are the invoice figures. This returns the \
            numbers, not a document: if the user wants the report as a PDF — "export it", \
            "save it", "send me the PDF" — use save_report_pdf instead. For raw tracked time \
            with no rounding and no money, use get_time_for_period instead.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("period")]),
            "properties": .object(inputProperties),
            "additionalProperties": .bool(false),
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    private static var inputProperties: [String: Value] {
        var properties = MCPPeriodArgument.schemaProperties
        properties["include_zero_time"] = .object([
            "type": .string("boolean"),
            "description": .string(
                "Also list tasks with no tracked time in the period. Defaults to false, "
                    + "matching the Report screen."
            ),
        ])
        properties["include_daily_breakdown"] = .object([
            "type": .string("boolean"),
            "description": .string(
                "Add a day-by-day breakdown to each task — the rows the PDF prints. "
                    + "Defaults to false; ask for it only when the question is about which "
                    + "days were worked, as it makes the response much larger."
            ),
        ])
        return properties
    }

    private let dataStore: any MCPDataReading
    private let preferences: any UserPreferencesService
    private let reportBuilder: any ReportBuilderService
    private let calendar: Calendar
    private let dateProvider: DateProvider

    init(
        dataStore: any MCPDataReading,
        preferences: any UserPreferencesService,
        reportBuilder: any ReportBuilderService = DefaultReportBuilderService(),
        calendar: Calendar = .current,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.dataStore = dataStore
        self.preferences = preferences
        self.reportBuilder = reportBuilder
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    // MARK: - MCP entry point

    func run(arguments: [String: Value]?) async -> CallTool.Result {
        let resolved = MCPPeriodArgument.resolve(
            arguments: arguments,
            fallback: nil,
            calendar: calendar,
            now: dateProvider.now()
        )

        switch resolved {
        case .failure(let failure):
            return MCPToolResponse.failure(failure.message)
        case .success(let period):
            let json = await payloadJSON(
                period: period,
                includeZeroTime: arguments?["include_zero_time"]?.boolValue ?? false,
                includeDailyBreakdown: arguments?["include_daily_breakdown"]?.boolValue ?? false
            )
            return MCPToolResponse.success(json)
        }
    }

    // MARK: - Handler logic

    /// The tool's whole behavior minus the MCP envelope, so it can be tested directly.
    func payloadJSON(
        period: MCPPeriodArgument.Resolved,
        includeZeroTime: Bool,
        includeDailyBreakdown: Bool
    ) async -> String {
        // The period's own calendar and clock go into the request, so the range the
        // response echoes is the range the numbers were computed over.
        //
        // Note this uses the period's real date range even for `all_time`, rather than
        // MCPPeriodArgument.Resolved.trackedTime(for:)'s `task.totalTrackedTime` shortcut:
        // the Report screen's "All Time" aggregates over distantPast…end of today, and
        // matching the screen is the whole point of this tool.
        let report = reportBuilder.buildReport(
            ReportRequest(
                tasks: await dataStore.fetchTasks(),
                startDate: period.start,
                endDate: period.end,
                includeZeroTime: includeZeroTime,
                preferences: preferences,
                calendar: period.calendar,
                now: period.now
            )
        )

        let payload = ReportBreakdownPayloadBuilder.build(
            report: report,
            period: period,
            preferences: ReportBreakdownPreferences(preferences: preferences),
            includeDailyBreakdown: includeDailyBreakdown
        )
        return MCPToolResponse.json(payload, fallbackMessage: "Failed to encode the report result.")
    }
}
