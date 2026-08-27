import Foundation
import MCP

/// MCP tool #1 — how much time went on one specific task the user named.
///
/// Search-first, because the caller knows the task by a rough name rather than by id.
/// Read-only.
struct TimeForTaskTool: Sendable {
    static let name = "get_time_for_task"

    static let definition = Tool(
        name: name,
        description: """
            How much time the user has tracked on ONE specific task or project they named. \
            Use this whenever the question mentions a task by name — "how much time did I \
            spend on the Acme redesign?". The query is free text, matched case-insensitively \
            against task titles and descriptions, and archived tasks are searched too. \
            Every matching task is returned with its own total and its id: this tool never \
            picks a single best match for you, and when nothing matches it returns no total \
            at all rather than a zero — say so instead of guessing a number. Covers any \
            period, defaulting to all time. If the question is about a span of time with no \
            particular task in mind, use get_time_for_period instead.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("query")]),
            "properties": .object(inputProperties),
            "additionalProperties": .bool(false),
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    private static var inputProperties: [String: Value] {
        var properties = MCPPeriodArgument.schemaProperties
        properties["query"] = .object([
            "type": .string("string"),
            "description": .string(
                "Free text identifying the task, matched case-insensitively against task "
                    + "titles and descriptions. Use the user's own wording; a partial name is fine."
            ),
        ])
        return properties
    }

    private let dataStore: any MCPDataReading
    private let calendar: Calendar
    private let dateProvider: DateProvider

    init(
        dataStore: any MCPDataReading,
        calendar: Calendar = .current,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.dataStore = dataStore
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    // MARK: - MCP entry point

    func run(arguments: [String: Value]?) async -> CallTool.Result {
        let query = arguments?["query"]?.stringValue ?? ""

        // An empty query would match every task, quietly doing get_time_for_period's job
        // under a name that promises a single task's total.
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MCPToolResponse.failure(
                "Missing \"query\". Pass the task name the user mentioned. To total a "
                    + "period across all tasks instead, call get_time_for_period."
            )
        }

        // No period argument means the all-time total.
        let resolved = MCPPeriodArgument.resolve(
            arguments: arguments,
            fallback: .allTime,
            calendar: calendar,
            now: dateProvider.now()
        )

        switch resolved {
        case .failure(let failure):
            return MCPToolResponse.failure(failure.message)
        case .success(let period):
            return MCPToolResponse.success(await payloadJSON(query: query, period: period))
        }
    }

    // MARK: - Handler logic

    /// The tool's whole behavior minus the MCP envelope, so it can be tested directly.
    func payloadJSON(query: String, period: MCPPeriodArgument.Resolved) async -> String {
        let payload = TimeForTaskPayloadBuilder.build(
            query: query,
            tasks: await dataStore.fetchTasks(),
            period: period
        )
        return MCPToolResponse.json(payload, fallbackMessage: "Failed to encode the task time result.")
    }
}
