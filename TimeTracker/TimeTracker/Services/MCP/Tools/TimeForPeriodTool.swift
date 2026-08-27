import Foundation
import MCP

/// MCP tool #2 — how much time the user tracked in a period, across all tasks.
///
/// Two response shapes for two different questions: one number for the period, or that
/// number plus every task's own total. Read-only.
struct TimeForPeriodTool: Sendable {
    static let name = "get_time_for_period"

    static let definition = Tool(
        name: name,
        description: """
            How much time the user tracked across all their tasks in a period. Use this \
            whenever the question is about a span of time rather than one named task — \
            "what have I tracked today?", "how much did I work this week / this month / \
            last month?", or any custom date range. Set breakdown to "per_task" for \
            questions like "...per task?" or "...broken down by task": that adds every task \
            with its own total, alongside the period total, which is always included. \
            Returns raw tracked time — no rounding and no hourly-rate amounts. If the user \
            named a specific task, use get_time_for_task instead.
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
        properties["breakdown"] = .object([
            "type": .string("string"),
            "enum": .array([
                .string(TimeForPeriodBreakdown.total.rawValue),
                .string(TimeForPeriodBreakdown.perTask.rawValue),
            ]),
            "description": .string(
                "\"total\" (default) returns a single number for the whole period. "
                    + "\"per_task\" also lists every task that has time in the period with its "
                    + "own total, sorted from most to least."
            ),
        ])
        properties["include_zero_time"] = .object([
            "type": .string("boolean"),
            "description": .string(
                "With breakdown \"per_task\", also list tasks with no tracked time in the "
                    + "period. Defaults to false."
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
                breakdown: TimeForPeriodBreakdown(argument: arguments?["breakdown"]?.stringValue),
                includeZeroTime: arguments?["include_zero_time"]?.boolValue ?? false
            )
            return MCPToolResponse.success(json)
        }
    }

    // MARK: - Handler logic

    /// The tool's whole behavior minus the MCP envelope, so it can be tested directly.
    func payloadJSON(
        period: MCPPeriodArgument.Resolved,
        breakdown: TimeForPeriodBreakdown,
        includeZeroTime: Bool
    ) async -> String {
        let payload = TimeForPeriodPayloadBuilder.build(
            tasks: await dataStore.fetchTasks(),
            period: period,
            breakdown: breakdown,
            includeZeroTime: includeZeroTime
        )
        return MCPToolResponse.json(payload, fallbackMessage: "Failed to encode the period time result.")
    }
}
