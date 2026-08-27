import Foundation
import MCP

/// MCP tool #5 — the discovery tool. Lets the caller see what tasks and tags actually
/// exist before asking questions about them, and resolve a rough task name to an id.
///
/// Read-only. Reuses the existing fetch paths via `MCPDataReading`; no new query logic.
struct ListTasksAndTagsTool: Sendable {
    static let name = "list_tasks_and_tags"

    static let definition = Tool(
        name: name,
        description: """
            List the tasks and tags that exist in the user's TimeTracker app, each task \
            with its id and total tracked time. Use this to discover what tasks exist, \
            to resolve a rough task name to an exact task id, or to offer the user a \
            choice when a name is ambiguous. Returns totals across all time — for time \
            in a specific period, use a time-query tool instead.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "include": .object([
                    "type": .string("string"),
                    "enum": .array([.string("active"), .string("archived"), .string("all")]),
                    "description": .string(
                        "Which tasks to list: \"active\" (default) omits archived tasks, "
                            + "\"archived\" returns only archived ones, \"all\" returns both."
                    ),
                ])
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    private let dataStore: any MCPDataReading

    init(dataStore: any MCPDataReading) {
        self.dataStore = dataStore
    }

    // MARK: - MCP entry point

    func run(arguments: [String: Value]?) async -> CallTool.Result {
        let filter = ListTasksFilter(argument: arguments?["include"]?.stringValue)
        return CallTool.Result(
            content: [.text(text: await payloadJSON(filter: filter), annotations: nil, _meta: nil)],
            isError: false
        )
    }

    // MARK: - Handler logic

    /// The tool's whole behavior minus the MCP envelope, so it can be tested directly.
    func payloadJSON(filter: ListTasksFilter) async -> String {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: await dataStore.fetchTasks(),
            tags: await dataStore.fetchTags(),
            filter: filter
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else {
            return #"{"error":"Failed to encode the task list."}"#
        }
        return String(decoding: data, as: UTF8.self)
    }
}
