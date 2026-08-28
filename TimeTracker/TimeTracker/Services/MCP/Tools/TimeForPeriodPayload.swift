import Foundation

/// Which shape `get_time_for_period` should return.
enum TimeForPeriodBreakdown: String, CaseIterable {
    /// One number for the whole period.
    case total
    /// Every task with its own total, plus the period total.
    case perTask = "per_task"

    static let fallback = TimeForPeriodBreakdown.total

    /// Anything unrecognised (including a missing argument) falls back to `total`, so a
    /// malformed call still answers the question instead of erroring. Same forgiving rule
    /// as `ListTasksFilter`.
    init(argument: String?) {
        guard let argument,
              let parsed = TimeForPeriodBreakdown(rawValue: argument.lowercased())
        else {
            self = .fallback
            return
        }
        self = parsed
    }
}

/// The JSON body returned by `get_time_for_period`.
struct TimeForPeriodPayload: Encodable, Equatable {

    struct TaskSummary: Encodable, Equatable {
        let id: String
        let title: String
        let isArchived: Bool
        let trackedTimeSeconds: Int
        let trackedTimeFormatted: String
    }

    let period: String
    /// Omitted for `all_time`.
    let startDate: String?
    let endDate: String?
    /// Which breakdown actually got applied, echoed so the caller can tell whether it got
    /// the default rather than what it asked for.
    let breakdown: String
    /// Always present, in both breakdowns, so the reader never has to add rows up.
    let totalTrackedTimeSeconds: Int
    let totalTrackedTimeFormatted: String
    /// Present only for the `per_task` breakdown.
    let taskCount: Int?
    let tasks: [TaskSummary]?
}

/// Turns domain models into the tool's JSON payload. Pure — no storage, no MCP.
enum TimeForPeriodPayloadBuilder {

    static func build(
        tasks: [TaskItem],
        period: MCPPeriodArgument.Resolved,
        breakdown: TimeForPeriodBreakdown,
        includeZeroTime: Bool
    ) -> TimeForPeriodPayload {
        // Every task's seconds are computed once, and the period total is the sum of those
        // same integers. So the total is identical in both breakdowns, and the rows always
        // add up to it — dropping zero-time rows can't change a sum they contribute 0 to.
        let summaries = tasks.map { task in
            let tracked = period.trackedTime(for: task)
            return TimeForPeriodPayload.TaskSummary(
                id: task.id.uuidString,
                title: task.title,
                isArchived: task.isArchived,
                trackedTimeSeconds: Int(tracked),
                trackedTimeFormatted: tracked.formattedHoursMinutes
            )
        }

        let total = summaries.reduce(0) { $0 + $1.trackedTimeSeconds }
        let bounds = period.formattedBounds

        guard breakdown == .perTask else {
            return TimeForPeriodPayload(
                period: period.name,
                startDate: bounds?.start,
                endDate: bounds?.end,
                breakdown: breakdown.rawValue,
                totalTrackedTimeSeconds: total,
                totalTrackedTimeFormatted: TimeInterval(total).formattedHoursMinutes,
                taskCount: nil,
                tasks: nil
            )
        }

        // Descending by time, matching how the Report screen already orders its rows.
        // Ties broken by title then id so identical inputs come back in the same order.
        let rows = summaries
            .filter { includeZeroTime || $0.trackedTimeSeconds > 0 }
            .sorted { lhs, rhs in
                if lhs.trackedTimeSeconds != rhs.trackedTimeSeconds {
                    return lhs.trackedTimeSeconds > rhs.trackedTimeSeconds
                }
                return lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
            }

        return TimeForPeriodPayload(
            period: period.name,
            startDate: bounds?.start,
            endDate: bounds?.end,
            breakdown: breakdown.rawValue,
            totalTrackedTimeSeconds: total,
            totalTrackedTimeFormatted: TimeInterval(total).formattedHoursMinutes,
            taskCount: rows.count,
            tasks: rows
        )
    }
}
