import Foundation

/// The JSON body returned by `get_time_for_task`.
///
/// The three match counts produce three deliberately different shapes: with no matches
/// there is **no total anywhere in the payload** for the AI to latch onto, with one match
/// there is no redundant "combined" figure, and with several every match carries its own
/// total alongside the combined one.
struct TimeForTaskPayload: Encodable, Equatable {

    struct Match: Encodable, Equatable {
        let id: String
        let title: String
        let description: String
        let isArchived: Bool
        let trackedTimeSeconds: Int
        let trackedTimeFormatted: String
    }

    let query: String
    let period: String
    /// Omitted for `all_time`.
    let startDate: String?
    let endDate: String?
    let matchCount: Int
    let matches: [Match]
    /// Present only when more than one task matched.
    let combinedTrackedTimeSeconds: Int?
    let combinedTrackedTimeFormatted: String?
    /// Guidance for the caller when the result needs interpreting rather than reporting.
    let message: String?
    /// Present only when nothing matched, as a hint for the follow-up question.
    let availableTaskCount: Int?
    let availableTaskTitles: [String]?
}

/// Turns domain models into the tool's JSON payload. Pure — no storage, no MCP.
enum TimeForTaskPayloadBuilder {

    /// How many task titles to offer as a hint when nothing matched. Enough to jog the
    /// user's memory, few enough not to bury the "no match" message itself.
    static let maximumHintTitles = 10

    static func build(
        query: String,
        tasks: [TaskItem],
        period: MCPPeriodArgument.Resolved
    ) -> TimeForTaskPayload {
        // The same predicate the Main Window search field uses: case-insensitive against
        // both title and description. Archived tasks are searched too — asking about a
        // finished project is a fair question — and flagged in the response.
        let matched = TaskSearch.filter(tasks, query: query)
            .map { task in
                let tracked = period.trackedTime(for: task)
                return TimeForTaskPayload.Match(
                    id: task.id.uuidString,
                    title: task.title,
                    description: task.taskDescription,
                    isArchived: task.isArchived,
                    trackedTimeSeconds: Int(tracked),
                    trackedTimeFormatted: tracked.formattedHoursMinutes
                )
            }
            .sorted { lhs, rhs in
                // Ties broken by title then id, so identical inputs always come back in
                // the same order.
                if lhs.trackedTimeSeconds != rhs.trackedTimeSeconds {
                    return lhs.trackedTimeSeconds > rhs.trackedTimeSeconds
                }
                return lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
            }

        let bounds = period.formattedBounds
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !matched.isEmpty else {
            let active = tasks.filter { !$0.isArchived }
            return TimeForTaskPayload(
                query: trimmedQuery,
                period: period.name,
                startDate: bounds?.start,
                endDate: bounds?.end,
                matchCount: 0,
                matches: [],
                combinedTrackedTimeSeconds: nil,
                combinedTrackedTimeFormatted: nil,
                message: """
                    No tasks matched "\(trimmedQuery)". Do not guess or estimate a number. \
                    Tell the user nothing matched and ask which task they meant, or call \
                    list_tasks_and_tags to see everything that exists.
                    """,
                availableTaskCount: active.count,
                availableTaskTitles: Array(active.prefix(maximumHintTitles).map(\.title))
            )
        }

        // Summing the per-match integer seconds rather than the raw intervals keeps the
        // combined figure equal to the sum of the numbers actually printed.
        let combined = matched.reduce(0) { $0 + $1.trackedTimeSeconds }

        return TimeForTaskPayload(
            query: trimmedQuery,
            period: period.name,
            startDate: bounds?.start,
            endDate: bounds?.end,
            matchCount: matched.count,
            matches: matched,
            combinedTrackedTimeSeconds: matched.count > 1 ? combined : nil,
            combinedTrackedTimeFormatted: matched.count > 1
                ? TimeInterval(combined).formattedHoursMinutes
                : nil,
            message: matched.count > 1
                ? """
                    \(matched.count) tasks matched "\(trimmedQuery)". Report each of them \
                    with its own total, or ask the user which one they meant — do not pick \
                    one on their behalf.
                    """
                : nil,
            availableTaskCount: nil,
            availableTaskTitles: nil
        )
    }
}
