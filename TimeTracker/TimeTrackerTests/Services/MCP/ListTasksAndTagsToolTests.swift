import Testing
import Foundation
import MCP
@testable import TimeTracker

struct ListTasksAndTagsToolTests {

    // MARK: - Fixtures

    private func makeTask(
        id: UUID = UUID(),
        title: String = "Task",
        isArchived: Bool = false,
        totalTrackedTime: TimeInterval = 0
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: isArchived,
            hourlyRate: nil,
            tags: [],
            timeEntries: [],
            totalTrackedTime: totalTrackedTime,
            trackedTimeToday: 0
        )
    }

    private func makeStore(
        tasks: [TaskItem] = [],
        tags: [TagItem] = []
    ) -> MockMCPDataStore {
        let store = MockMCPDataStore()
        store.stubbedTasks = tasks
        store.stubbedTags = tags
        return store
    }

    /// The tool returns a JSON string; decode it back so tests assert on values rather
    /// than on formatting.
    private func decode(_ json: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [String: Any])
    }

    // MARK: - Payload

    @Test func payloadIsValidJSONDescribingTasksAndTags() async throws {
        let store = makeStore(
            tasks: [makeTask(title: "Invoicing", totalTrackedTime: 3600)],
            tags: [TagItem(id: UUID(), name: "Acme", colorHex: "#FFFFFF", createdAt: Date())]
        )
        let tool = ListTasksAndTagsTool(dataStore: store)

        let root = try decode(await tool.payloadJSON(filter: .active))

        #expect(root["taskCount"] as? Int == 1)
        #expect(root["tagCount"] as? Int == 1)
        #expect(root["filter"] as? String == "active")

        let tasks = try #require(root["tasks"] as? [[String: Any]])
        #expect(tasks.first?["title"] as? String == "Invoicing")
        #expect(tasks.first?["totalTrackedTimeFormatted"] as? String == "1h 00m")

        let tags = try #require(root["tags"] as? [[String: Any]])
        #expect(tags.first?["name"] as? String == "Acme")
    }

    @Test func payloadReadsBothTasksAndTagsFromStorage() async {
        let store = makeStore()
        let tool = ListTasksAndTagsTool(dataStore: store)

        _ = await tool.payloadJSON(filter: .all)

        #expect(store.fetchTasksCallCount == 1)
        #expect(store.fetchTagsCallCount == 1)
    }

    // MARK: - Argument handling

    @Test func missingArgumentsListActiveTasksOnly() async throws {
        let store = makeStore(tasks: [
            makeTask(title: "Live", isArchived: false),
            makeTask(title: "Old", isArchived: true),
        ])
        let tool = ListTasksAndTagsTool(dataStore: store)

        let root = try decode(try #require(text(from: await tool.run(arguments: nil))))
        let tasks = try #require(root["tasks"] as? [[String: Any]])

        #expect(tasks.map { $0["title"] as? String } == ["Live"])
        #expect(root["filter"] as? String == "active")
    }

    @Test func includeAllReturnsArchivedTasksToo() async throws {
        let store = makeStore(tasks: [
            makeTask(title: "Live", isArchived: false),
            makeTask(title: "Old", isArchived: true),
        ])
        let tool = ListTasksAndTagsTool(dataStore: store)

        let result = await tool.run(arguments: ["include": .string("all")])
        let root = try decode(try #require(text(from: result)))
        let tasks = try #require(root["tasks"] as? [[String: Any]])

        #expect(tasks.count == 2)
        #expect(root["filter"] as? String == "all")
    }

    @Test func unrecognisedIncludeValueFallsBackToActiveRatherThanErroring() async throws {
        let store = makeStore(tasks: [makeTask(title: "Old", isArchived: true)])
        let tool = ListTasksAndTagsTool(dataStore: store)

        let result = await tool.run(arguments: ["include": .string("nonsense")])

        #expect(result.isError == false)
        let root = try decode(try #require(text(from: result)))
        #expect(root["filter"] as? String == "active")
        #expect((root["tasks"] as? [[String: Any]])?.isEmpty == true)
    }

    // MARK: - Tool definition

    @Test func definitionAdvertisesTheThreeIncludeValues() throws {
        guard case .object(let schema) = ListTasksAndTagsTool.definition.inputSchema,
              case .object(let properties)? = schema["properties"],
              case .object(let include)? = properties["include"],
              case .array(let allowed)? = include["enum"]
        else {
            Issue.record("Unexpected input schema shape")
            return
        }

        #expect(allowed == [.string("active"), .string("archived"), .string("all")])
    }

    @Test func definitionIsMarkedReadOnly() {
        #expect(ListTasksAndTagsTool.definition.annotations.readOnlyHint == true)
    }

    // MARK: - Helpers

    private func text(from result: CallTool.Result) -> String? {
        for content in result.content {
            if case .text(let text, _, _) = content { return text }
        }
        return nil
    }
}
