import Testing
import Foundation
import MCP
@testable import TimeTracker

struct TimeForTaskToolTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Wednesday 18 February 2026, 12:00.
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
        description: String = "",
        isArchived: Bool = false,
        entries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: description,
            createdAt: Date(),
            isArchived: isArchived,
            hourlyRate: nil,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    private func makeTool(tasks: [TaskItem]) -> TimeForTaskTool {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        let dateProvider = MockDateProvider()
        dateProvider.currentDate = now
        return TimeForTaskTool(dataStore: store, calendar: calendar, dateProvider: dateProvider)
    }

    private func call(
        _ tool: TimeForTaskTool,
        query: String?,
        period: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> CallTool.Result {
        var arguments: [String: Value] = [:]
        if let query { arguments["query"] = .string(query) }
        if let period { arguments["period"] = .string(period) }
        if let startDate { arguments["start_date"] = .string(startDate) }
        if let endDate { arguments["end_date"] = .string(endDate) }
        return await tool.run(arguments: arguments)
    }

    private func payload(
        tasks: [TaskItem],
        query: String?,
        period: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> [String: Any] {
        let result = await call(
            makeTool(tasks: tasks),
            query: query,
            period: period,
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

    // MARK: - No matches

    @Test func noMatchesIsAnAnswerRatherThanAnError() async throws {
        let result = await call(makeTool(tasks: [task(title: "Invoicing")]), query: "gardening")

        #expect(result.isError == false)
        let root = try decode(try #require(text(from: result)))
        #expect(root["matchCount"] as? Int == 0)
        #expect((root["matches"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test func noMatchesCarriesNoTotalAnywhereInThePayload() async throws {
        let root = try await payload(
            tasks: [task(title: "Invoicing", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 17))])],
            query: "gardening"
        )

        // Nothing anywhere for the AI to mistake for an answer.
        #expect(root["combinedTrackedTimeSeconds"] == nil)
        #expect(root["combinedTrackedTimeFormatted"] == nil)
        let keysMentioningTime = root.keys.filter { $0.localizedCaseInsensitiveContains("trackedTime") }
        #expect(keysMentioningTime.isEmpty)
    }

    @Test func noMatchesHintsAtTheTasksThatDoExist() async throws {
        let root = try await payload(
            tasks: [task(title: "Invoicing"), task(title: "Design"), task(title: "Archived", isArchived: true)],
            query: "gardening"
        )

        #expect(root["availableTaskCount"] as? Int == 2)
        let titles = try #require(root["availableTaskTitles"] as? [String])
        #expect(titles == ["Invoicing", "Design"])
        #expect((root["message"] as? String)?.isEmpty == false)
    }

    @Test func noMatchesCapsTheHintTitles() async throws {
        let many = (1...25).map { task(title: "Task \($0)") }
        let root = try await payload(tasks: many, query: "gardening")

        let titles = try #require(root["availableTaskTitles"] as? [String])
        #expect(titles.count == TimeForTaskPayloadBuilder.maximumHintTitles)
        #expect(root["availableTaskCount"] as? Int == 25)
    }

    // MARK: - One match

    @Test func oneMatchReturnsThatTaskWithItsTotalAndId() async throws {
        let id = UUID()
        let root = try await payload(
            tasks: [
                task(id: id, title: "Invoicing", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11))]),
                task(title: "Design"),
            ],
            query: "invoic"
        )

        #expect(root["matchCount"] as? Int == 1)
        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(matches.count == 1)
        #expect(matches[0]["id"] as? String == id.uuidString)
        #expect(matches[0]["title"] as? String == "Invoicing")
        #expect(matches[0]["trackedTimeSeconds"] as? Int == 2 * 3600)
        #expect(matches[0]["trackedTimeFormatted"] as? String == "2h 00m")
    }

    @Test func oneMatchOmitsTheRedundantCombinedTotal() async throws {
        let root = try await payload(tasks: [task(title: "Invoicing")], query: "invoic")

        #expect(root["combinedTrackedTimeSeconds"] == nil)
        #expect(root["message"] == nil)
    }

    // MARK: - Many matches

    @Test func severalMatchesAreAllReturnedWithTheirOwnTotals() async throws {
        let root = try await payload(
            tasks: [
                task(title: "Invoicing Acme", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 10))]),
                task(title: "Invoicing Globex", entries: [entry(start: date(2026, 2, 11, 9), end: date(2026, 2, 11, 12))]),
                task(title: "Design"),
            ],
            query: "invoicing"
        )

        #expect(root["matchCount"] as? Int == 2)
        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(matches.map { $0["title"] as? String } == ["Invoicing Globex", "Invoicing Acme"])
        #expect(matches.map { $0["trackedTimeSeconds"] as? Int } == [3 * 3600, 3600])
    }

    @Test func severalMatchesAlsoCarryACombinedTotal() async throws {
        let root = try await payload(
            tasks: [
                task(title: "Invoicing Acme", entries: [entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 10))]),
                task(title: "Invoicing Globex", entries: [entry(start: date(2026, 2, 11, 9), end: date(2026, 2, 11, 12))]),
            ],
            query: "invoicing"
        )

        #expect(root["combinedTrackedTimeSeconds"] as? Int == 4 * 3600)
        #expect(root["combinedTrackedTimeFormatted"] as? String == "4h 00m")
    }

    @Test func severalMatchesTellTheCallerNotToPickOne() async throws {
        let root = try await payload(
            tasks: [task(title: "Invoicing Acme"), task(title: "Invoicing Globex")],
            query: "invoicing"
        )

        let message = try #require(root["message"] as? String)
        #expect(message.contains("2 tasks matched"))
    }

    @Test func everyMatchCarriesItsIdSoAFollowUpCanTargetIt() async throws {
        let first = UUID()
        let second = UUID()
        let root = try await payload(
            tasks: [task(id: first, title: "Invoicing Acme"), task(id: second, title: "Invoicing Globex")],
            query: "invoicing"
        )

        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(Set(matches.compactMap { $0["id"] as? String }) == [first.uuidString, second.uuidString])
    }

    // MARK: - Searching

    @Test func theDescriptionIsSearchedAsWellAsTheTitle() async throws {
        let root = try await payload(
            tasks: [task(title: "Acme", description: "Monthly invoicing run")],
            query: "invoicing"
        )

        #expect(root["matchCount"] as? Int == 1)
    }

    @Test func searchIsCaseInsensitive() async throws {
        let root = try await payload(tasks: [task(title: "Invoicing")], query: "INVOICING")

        #expect(root["matchCount"] as? Int == 1)
    }

    @Test func archivedTasksAreMatchedAndFlagged() async throws {
        let root = try await payload(tasks: [task(title: "Invoicing", isArchived: true)], query: "invoic")

        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(matches.count == 1)
        #expect(matches[0]["isArchived"] as? Bool == true)
    }

    @Test func aMissingOrBlankQueryIsRejected() async {
        let tool = makeTool(tasks: [task(title: "Invoicing")])

        let missing = await tool.run(arguments: nil)
        let blank = await call(tool, query: "   ")

        #expect(missing.isError == true)
        #expect(blank.isError == true)
        // The error must point at the tool that does answer this.
        #expect(text(from: blank)?.contains("get_time_for_period") == true)
    }

    // MARK: - Periods

    @Test func noPeriodArgumentReturnsTheAllTimeTotal() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Invoicing",
                    entries: [
                        entry(start: date(2025, 6, 1, 9), end: date(2025, 6, 1, 14)),
                        entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11)),
                    ]
                )
            ],
            query: "invoic"
        )

        #expect(root["period"] as? String == "all_time")
        #expect(root["startDate"] == nil)
        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(matches[0]["trackedTimeSeconds"] as? Int == 7 * 3600)
    }

    @Test func aPeriodNarrowsTheTotalToThatRange() async throws {
        let tasks = [
            task(
                title: "Invoicing",
                entries: [
                    entry(start: date(2025, 6, 1, 9), end: date(2025, 6, 1, 14)),
                    entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11)),
                ]
            )
        ]

        let root = try await payload(tasks: tasks, query: "invoic", period: "this_month")
        let matches = try #require(root["matches"] as? [[String: Any]])

        #expect(root["period"] as? String == "this_month")
        #expect(root["startDate"] as? String == "2026-02-01")
        #expect(root["endDate"] as? String == "2026-02-28")
        #expect(matches[0]["trackedTimeSeconds"] as? Int == 2 * 3600)
    }

    @Test func aCustomRangeIsHonoured() async throws {
        let root = try await payload(
            tasks: [
                task(
                    title: "Invoicing",
                    entries: [
                        entry(start: date(2026, 2, 10, 9), end: date(2026, 2, 10, 11)),
                        entry(start: date(2026, 2, 14, 9), end: date(2026, 2, 14, 13)),
                    ]
                )
            ],
            query: "invoic",
            period: "custom",
            startDate: "2026-02-01",
            endDate: "2026-02-12"
        )

        let matches = try #require(root["matches"] as? [[String: Any]])
        #expect(matches[0]["trackedTimeSeconds"] as? Int == 2 * 3600)
        #expect(root["endDate"] as? String == "2026-02-12")
    }

    @Test func aMalformedPeriodIsAnErrorTheCallerCanFix() async throws {
        let result = await call(makeTool(tasks: [task(title: "Invoicing")]), query: "invoic", period: "last_fortnight")

        #expect(result.isError == true)
        #expect(text(from: result)?.contains("\"this_month\"") == true)
    }

    // MARK: - Tool definition

    @Test func definitionRequiresOnlyTheQuery() throws {
        guard case .object(let schema) = TimeForTaskTool.definition.inputSchema,
              case .array(let required)? = schema["required"]
        else {
            Issue.record("Unexpected input schema shape")
            return
        }

        #expect(required == [.string("query")])
    }

    @Test func definitionAdvertisesTheSharedPeriodArgument() throws {
        guard case .object(let schema) = TimeForTaskTool.definition.inputSchema,
              case .object(let properties)? = schema["properties"]
        else {
            Issue.record("Unexpected input schema shape")
            return
        }

        #expect(properties["period"] != nil)
        #expect(properties["start_date"] != nil)
        #expect(properties["end_date"] != nil)
        #expect(properties["query"] != nil)
    }

    @Test func definitionIsMarkedReadOnly() {
        #expect(TimeForTaskTool.definition.annotations.readOnlyHint == true)
        #expect(TimeForTaskTool.definition.annotations.openWorldHint == false)
    }

    @Test func definitionPointsAtTheOtherToolSoTheTwoDontGetConfused() {
        #expect(TimeForTaskTool.definition.description?.contains(TimeForPeriodTool.name) == true)
    }
}
