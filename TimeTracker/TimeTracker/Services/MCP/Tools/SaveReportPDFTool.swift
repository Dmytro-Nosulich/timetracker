import Foundation
import MCP

/// MCP tool #4 — the same report `get_billable_report` returns as numbers, rendered to a
/// PDF and written to disk.
///
/// The one tool on this server that writes anything, and the reason the app gave up its
/// App Sandbox: the motivating use case is a scheduled skill producing last month's report
/// unattended, so **no save panel and no dialog of any kind may appear**. Everything from
/// the tasks to the totals runs through the same `DefaultReportBuilderService` and
/// `CoreGraphicsReportPDFService` the Report screen's own export uses, so a file produced
/// here and one produced by hand are the same document.
struct SaveReportPDFTool: Sendable {
    static let name = "save_report_pdf"

    static let definition = Tool(
        name: name,
        description: """
            Generates the user's time report as a PDF and SAVES IT TO A FILE on disk, then \
            returns the path it wrote. Use this whenever the user wants a report as a \
            document — "export", "save", "generate the PDF", "send me last month's report" \
            — or names a place to put it, like the Desktop. The PDF is identical to the one \
            the app's Report screen exports for the same period: their rounding applied, \
            rates resolved, amounts computed. It never overwrites an existing file; if the \
            name is taken it saves as "… (2).pdf" and tells you. If the user only wants to \
            know the numbers and not to have a file, use get_billable_report instead.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("period"), .string("destination_path")]),
            "properties": .object(inputProperties),
            "additionalProperties": .bool(false),
        ]),
        // Not read-only: it writes a file. Not destructive, though — an existing file is
        // never replaced, so the worst case is an extra document. Not idempotent for the
        // same reason: calling twice leaves two files.
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        )
    )

    private static var inputProperties: [String: Value] {
        var properties = MCPPeriodArgument.schemaProperties
        properties["destination_path"] = .object([
            "type": .string("string"),
            "description": .string(
                "Where to save. Either a folder that already exists, e.g. \"~/Desktop\", in "
                    + "which case the report is named automatically, or a full path ending in "
                    + "\".pdf\". \"~\" is expanded. Folders are never created. If the user did "
                    + "not say where to put it, use \"~/Desktop\" rather than inventing a path."
            ),
        ])
        properties["filename"] = .object([
            "type": .string("string"),
            "description": .string(
                "Optional name for the file when destination_path is a folder. \".pdf\" is "
                    + "added if missing. Leave it out to use the app's own name for the "
                    + "period, e.g. \"Time Report - July 2026.pdf\"."
            ),
        ])
        properties["task_query"] = .object([
            "type": .string("string"),
            "description": .string(
                "Optional free text limiting the report to matching tasks, matched "
                    + "case-insensitively against task titles and descriptions — the same "
                    + "search get_time_for_task uses. Leave it out to report every task."
            ),
        ])
        return properties
    }

    private let dataStore: any MCPDataReading
    private let preferences: any UserPreferencesService
    private let reportBuilder: any ReportBuilderService
    private let pdfService: any ReportPDFService
    private let fileWriter: any MCPFileWriting
    private let calendar: Calendar
    private let dateProvider: DateProvider

    init(
        dataStore: any MCPDataReading,
        preferences: any UserPreferencesService,
        reportBuilder: any ReportBuilderService = DefaultReportBuilderService(),
        pdfService: any ReportPDFService = CoreGraphicsReportPDFService(),
        fileWriter: any MCPFileWriting = DefaultMCPFileWriter(),
        calendar: Calendar = .current,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.dataStore = dataStore
        self.preferences = preferences
        self.reportBuilder = reportBuilder
        self.pdfService = pdfService
        self.fileWriter = fileWriter
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
            return await save(
                period: period,
                destinationPath: arguments?["destination_path"]?.stringValue,
                filename: arguments?["filename"]?.stringValue,
                taskQuery: arguments?["task_query"]?.stringValue
            )
        }
    }

    // MARK: - Handler logic

    /// The tool's whole behavior minus the period parsing, so it can be tested directly.
    ///
    /// Ordered so the cheap failures come first: there is no point rendering a PDF for a
    /// destination that was never going to accept it.
    func save(
        period: MCPPeriodArgument.Resolved,
        destinationPath: String?,
        filename: String?,
        taskQuery: String?
    ) async -> CallTool.Result {
        let query = taskQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuery = (query?.isEmpty == false) ? query : nil

        let allTasks = await dataStore.fetchTasks()
        let tasks = effectiveQuery.map { TaskSearch.filter(allTasks, query: $0) } ?? allTasks

        // A filter that matched nothing would otherwise render a blank report and save it
        // as though it were the user's month. Failing is the kinder answer.
        if let effectiveQuery, tasks.isEmpty {
            return MCPToolResponse.failure(
                "No task matches \"\(effectiveQuery)\", so no PDF was written. Call "
                    + "list_tasks_and_tags to see the task names, or drop task_query to "
                    + "report every task."
            )
        }

        // includeZeroTime: false is what the Report screen defaults to, so the task set
        // here is the task set a manual export would have produced.
        let report = reportBuilder.buildReport(
            ReportRequest(
                tasks: tasks,
                startDate: period.start,
                endDate: period.end,
                includeZeroTime: false,
                preferences: preferences,
                calendar: period.calendar,
                now: period.now
            )
        )

        guard !report.taskSummaries.isEmpty else {
            return MCPToolResponse.failure(emptyReportMessage(period: period, query: effectiveQuery))
        }

        let destination = ReportPDFDestination.resolve(
            path: destinationPath,
            filename: filename,
            defaultFilename: period.period.defaultFilename(startDate: period.start, endDate: period.end),
            fileWriter: fileWriter
        )

        switch destination {
        case .failure(let failure):
            return MCPToolResponse.failure(failure.message)
        case .success(let resolved):
            return await write(report: report, to: resolved, period: period, query: effectiveQuery)
        }
    }

    // MARK: - Private

    private func write(
        report: ReportData,
        to destination: ReportPDFDestination.Resolved,
        period: MCPPeriodArgument.Resolved,
        query: String?
    ) async -> CallTool.Result {
        let currencySymbol = preferences.currencySymbol
        let config = reportBuilder.makePDFConfig(
            for: report,
            presentation: ReportPresentation(
                businessName: preferences.businessName,
                currencySymbol: currencySymbol,
                generatedDate: dateProvider.now()
            )
        )

        // CoreGraphicsReportPDFService draws with NSFont/NSColor/NSAttributedString, which
        // are not documented safe off the main thread — and this handler runs on one of
        // NIO's event loops. The render is fast and rare, so the hop costs nothing.
        let data = await MainActor.run { pdfService.generatePDF(config: config) }

        do {
            try fileWriter.write(data, to: destination.url)
        } catch {
            return MCPToolResponse.failure(
                "Could not write to \"\(destination.url.path)\": \(error.localizedDescription) "
                    + "The report itself was generated fine — only saving failed, so a "
                    + "different destination_path should work."
            )
        }

        let payload = SaveReportPDFPayloadBuilder.build(
            destination: destination,
            report: report,
            period: period,
            currencySymbol: currencySymbol,
            taskQuery: query,
            fileSizeBytes: data.count
        )
        return MCPToolResponse.success(
            MCPToolResponse.json(payload, fallbackMessage: "Saved the PDF but failed to encode the result.")
        )
    }

    private func emptyReportMessage(period: MCPPeriodArgument.Resolved, query: String?) -> String {
        let scope = query.map { " matching \"\($0)\"" } ?? ""
        return "No time is tracked\(scope) in the period \"\(period.name)\", so no PDF was "
            + "written — an empty report is not worth saving. Call get_time_for_period to "
            + "check which periods have time in them."
    }
}
