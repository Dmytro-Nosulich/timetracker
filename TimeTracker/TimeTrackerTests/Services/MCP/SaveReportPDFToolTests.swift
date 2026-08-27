import Testing
import Foundation
import MCP
@testable import TimeTracker

struct SaveReportPDFToolTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Wednesday 18 February 2026, 12:00 — so `last_month` is January 2026.
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
        description: String = "",
        hourlyRate: Double? = nil,
        entries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: description,
            createdAt: Date(),
            isArchived: false,
            hourlyRate: hourlyRate,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    /// One task with two hours in January 2026.
    private func januaryTask(title: String = "Acme redesign", hourlyRate: Double? = 50) -> TaskItem {
        task(
            title: title,
            hourlyRate: hourlyRate,
            entries: [entry(start: date(2026, 1, 15, 9), end: date(2026, 1, 15, 11))]
        )
    }

    private func makeTool(
        tasks: [TaskItem],
        preferences: MockUserPreferencesService = MockUserPreferencesService(),
        pdfService: (any ReportPDFService)? = nil,
        fileWriter: (any MCPFileWriting)? = nil
    ) -> SaveReportPDFTool {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        let dateProvider = MockDateProvider()
        dateProvider.currentDate = now

        return SaveReportPDFTool(
            dataStore: store,
            preferences: preferences,
            pdfService: pdfService ?? CoreGraphicsReportPDFService(),
            fileWriter: fileWriter ?? DefaultMCPFileWriter(),
            calendar: calendar,
            dateProvider: dateProvider
        )
    }

    private func call(
        _ tool: SaveReportPDFTool,
        period: String? = "last_month",
        destinationPath: String?,
        filename: String? = nil,
        taskQuery: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> CallTool.Result {
        var arguments: [String: Value] = [:]
        if let period { arguments["period"] = .string(period) }
        if let destinationPath { arguments["destination_path"] = .string(destinationPath) }
        if let filename { arguments["filename"] = .string(filename) }
        if let taskQuery { arguments["task_query"] = .string(taskQuery) }
        if let startDate { arguments["start_date"] = .string(startDate) }
        if let endDate { arguments["end_date"] = .string(endDate) }
        return await tool.run(arguments: arguments)
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

    private func payload(from result: CallTool.Result) throws -> [String: Any] {
        #expect(result.isError == false)
        return try decode(try #require(text(from: result)))
    }

    /// A real, empty directory that cleans itself up. The write path is worth exercising
    /// against an actual filesystem — the error messages this tool returns are its product.
    private func withTemporaryDirectory(_ body: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveReportPDFToolTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await body(directory)
    }

    // MARK: - Writing

    @Test func itWritesARealPDFToTheGivenFolder() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [januaryTask()])

            let result = await call(tool, destinationPath: directory.path)
            let payload = try payload(from: result)

            let path = try #require(payload["path"] as? String)
            #expect(payload["filename"] as? String == "Time Report - January 2026.pdf")
            #expect(payload["directory"] as? String == directory.path)
            #expect(FileManager.default.fileExists(atPath: path))

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            #expect(data.starts(with: Array("%PDF".utf8)))
            #expect(payload["fileSizeBytes"] as? Int == data.count)
        }
    }

    @Test func itNeverShowsADialogAndReportsTheFiguresTheReportContains() async throws {
        try await withTemporaryDirectory { directory in
            let preferences = MockUserPreferencesService()
            preferences.stubbedCurrencySymbol = "€"
            let tool = makeTool(tasks: [januaryTask()], preferences: preferences)

            let payload = try payload(from: await call(tool, destinationPath: directory.path))

            #expect(payload["period"] as? String == "last_month")
            #expect(payload["startDate"] as? String == "2026-01-01")
            #expect(payload["endDate"] as? String == "2026-01-31")
            #expect(payload["taskCount"] as? Int == 1)
            #expect(payload["totalRoundedTimeFormatted"] as? String == "2h 00m")
            #expect(payload["totalAmountFormatted"] as? String == CurrencyFormatting.amount(100, symbol: "€"))
            #expect(payload["renamedToAvoidOverwrite"] as? Bool == false)
            #expect(payload["requestedFilename"] == nil)
            #expect(payload["taskQuery"] == nil)
        }
    }

    @Test func aFilenameOverrideIsHonoured() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [januaryTask()])

            let payload = try payload(
                from: await call(tool, destinationPath: directory.path, filename: "January invoice")
            )

            #expect(payload["filename"] as? String == "January invoice.pdf")
            #expect(FileManager.default.fileExists(atPath: try #require(payload["path"] as? String)))
        }
    }

    @Test func aFullFilePathIsWrittenAsGiven() async throws {
        try await withTemporaryDirectory { directory in
            let target = directory.appendingPathComponent("report.pdf")
            let tool = makeTool(tasks: [januaryTask()])

            let payload = try payload(from: await call(tool, destinationPath: target.path))

            #expect(payload["path"] as? String == target.path)
            #expect(FileManager.default.fileExists(atPath: target.path))
        }
    }

    /// The motivating use case is a monthly skill that re-runs. A second run must not
    /// quietly replace a PDF that has already been invoiced from.
    @Test func asecondCallToTheSameFolderRenamesInsteadOfOverwriting() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [januaryTask()])

            let first = try payload(from: await call(tool, destinationPath: directory.path))
            let second = try payload(from: await call(tool, destinationPath: directory.path))

            #expect(first["filename"] as? String == "Time Report - January 2026.pdf")
            #expect(second["filename"] as? String == "Time Report - January 2026 (2).pdf")
            #expect(second["renamedToAvoidOverwrite"] as? Bool == true)
            #expect(second["requestedFilename"] as? String == "Time Report - January 2026.pdf")
            #expect(FileManager.default.fileExists(atPath: try #require(first["path"] as? String)))
            #expect(FileManager.default.fileExists(atPath: try #require(second["path"] as? String)))
        }
    }

    // MARK: - Task filter

    @Test func aTaskQueryNarrowsTheReportAndIsEchoedBack() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [
                januaryTask(title: "Acme redesign"),
                task(
                    title: "Globex migration",
                    hourlyRate: 50,
                    entries: [entry(start: date(2026, 1, 20, 9), end: date(2026, 1, 20, 14))]
                ),
            ])

            let payload = try payload(
                from: await call(tool, destinationPath: directory.path, taskQuery: "acme")
            )

            #expect(payload["taskCount"] as? Int == 1)
            #expect(payload["taskQuery"] as? String == "acme")
            #expect(payload["totalRoundedTimeFormatted"] as? String == "2h 00m")
        }
    }

    @Test func aTaskQueryMatchesDescriptionsTooLikeTheOtherSearch() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [
                task(
                    title: "Redesign",
                    description: "For Globex",
                    hourlyRate: 50,
                    entries: [entry(start: date(2026, 1, 15, 9), end: date(2026, 1, 15, 11))]
                ),
            ])

            let payload = try payload(
                from: await call(tool, destinationPath: directory.path, taskQuery: "globex")
            )

            #expect(payload["taskCount"] as? Int == 1)
        }
    }

    /// Saving a blank document as though it were the user's month is worse than failing.
    @Test func aTaskQueryMatchingNothingWritesNoFile() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [januaryTask()])

            let result = await call(tool, destinationPath: directory.path, taskQuery: "nothing matches this")

            #expect(result.isError == true)
            let message = try #require(text(from: result))
            #expect(message.contains("nothing matches this"))
            #expect(message.contains("list_tasks_and_tags"))
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test func aPeriodWithNoTrackedTimeWritesNoFile() async throws {
        try await withTemporaryDirectory { directory in
            let tool = makeTool(tasks: [januaryTask()])

            // The task's only time is in January; "today" is 18 February.
            let result = await call(tool, period: "today", destinationPath: directory.path)

            #expect(result.isError == true)
            let message = try #require(text(from: result))
            #expect(message.contains("today"))
            #expect(message.contains("get_time_for_period"))
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    // MARK: - Argument errors

    @Test func aMissingDestinationPathIsAnError() async throws {
        let tool = makeTool(tasks: [januaryTask()])

        let result = await call(tool, destinationPath: nil)

        #expect(result.isError == true)
        #expect(try #require(text(from: result)).contains("destination_path"))
    }

    @Test func aMissingPeriodIsAnErrorNamingTheAcceptedValues() async throws {
        let tool = makeTool(tasks: [januaryTask()])

        let result = await call(tool, period: nil, destinationPath: "/tmp")

        #expect(result.isError == true)
        #expect(try #require(text(from: result)).contains("last_month"))
    }

    @Test func anUnknownPeriodIsAnError() async throws {
        let tool = makeTool(tasks: [januaryTask()])

        let result = await call(tool, period: "last_fortnight", destinationPath: "/tmp")

        #expect(result.isError == true)
        #expect(try #require(text(from: result)).contains("last_fortnight"))
    }

    @Test func aFolderThatDoesNotExistIsAnErrorNamingThePath() async throws {
        let tool = makeTool(tasks: [januaryTask()])

        let result = await call(tool, destinationPath: "/tmp/definitely-not-here-\(UUID().uuidString)")

        #expect(result.isError == true)
        #expect(try #require(text(from: result)).contains("does not exist"))
    }

    /// A destination that resolves fine but the OS refuses. The message has to be
    /// actionable — this is what a scheduled skill will surface at 3am.
    @Test func anUnwritableLocationFailsWithAReadableMessage() async throws {
        let tool = makeTool(tasks: [januaryTask()])

        let result = await call(tool, destinationPath: "/System/Library/report.pdf")

        #expect(result.isError == true)
        let message = try #require(text(from: result))
        #expect(message.contains("/System/Library"))
    }

    @Test func aFailedWriteIsReportedRatherThanCrashing() async throws {
        let writer = MockMCPFileWriter()
        writer.stubbedDirectories = ["/Users/test/Desktop"]
        writer.stubbedWriteError = CocoaError(.fileWriteNoPermission)
        let tool = makeTool(tasks: [januaryTask()], fileWriter: writer)

        let result = await call(tool, destinationPath: "/Users/test/Desktop")

        #expect(result.isError == true)
        let message = try #require(text(from: result))
        #expect(message.contains("/Users/test/Desktop/Time Report - January 2026.pdf"))
        #expect(message.contains("destination_path"))
    }

    // MARK: - Wiring

    @Test func theReportIsRenderedThroughTheSharedPDFService() async throws {
        let pdfService = MockReportPDFService()
        let writer = MockMCPFileWriter()
        writer.stubbedDirectories = ["/Users/test/Desktop"]
        let preferences = MockUserPreferencesService()
        preferences.stubbedBusinessName = "Acme Consulting"
        preferences.stubbedCurrencySymbol = "€"
        let tool = makeTool(
            tasks: [januaryTask()],
            preferences: preferences,
            pdfService: pdfService,
            fileWriter: writer
        )

        _ = await call(tool, destinationPath: "/Users/test/Desktop")

        #expect(pdfService.generatePDFCallCount == 1)
        let config = try #require(pdfService.generatePDFLastConfig)
        #expect(config.businessName == "Acme Consulting")
        #expect(config.currencySymbol == "€")
        #expect(config.totalTime == "2h 00m")
        #expect(writer.writeCallCount == 1)
        #expect(writer.writeLastData == pdfService.stubbedPDFData)
    }

    @Test func theToolIsAdvertisedAsWritingRatherThanReadOnly() {
        let annotations = try? #require(SaveReportPDFTool.definition.annotations)

        #expect(annotations?.readOnlyHint == false)
        #expect(annotations?.destructiveHint == false)
        #expect(annotations?.openWorldHint == false)
        #expect(SaveReportPDFTool.name == "save_report_pdf")
    }
}
