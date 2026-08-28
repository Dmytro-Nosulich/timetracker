import Foundation
import MCP

/// The date-period argument shared by the time-query tools, so every tool that asks
/// "which period?" accepts exactly the same values and resolves them the same way.
///
/// Wraps the existing `ReportPeriod` rather than inventing a second period vocabulary:
/// its `dateRange(calendar:now:)` stays the single definition of where "this week" starts.
/// The MCP surface uses snake_case names instead of `ReportPeriod`'s display raw values
/// ("This Week"), because those are what an AI caller reliably produces.
enum MCPPeriodArgument {

    // MARK: - Names

    /// The snake_case name each period is known by over MCP.
    static let names: [ReportPeriod: String] = [
        .today: "today",
        .thisWeek: "this_week",
        .lastWeek: "last_week",
        .thisMonth: "this_month",
        .lastMonth: "last_month",
        .thisYear: "this_year",
        .allTime: "all_time",
        .customRange: "custom",
    ]

    /// The advertised order, which is also the order the enum values appear in the schema.
    static let orderedPeriods: [ReportPeriod] = [
        .today, .thisWeek, .lastWeek, .thisMonth, .lastMonth, .thisYear, .allTime, .customRange,
    ]

    static func name(for period: ReportPeriod) -> String {
        names[period] ?? period.rawValue
    }

    // MARK: - Schema

    /// The `properties` entries every period-taking tool merges into its input schema.
    static let schemaProperties: [String: Value] = [
        "period": .object([
            "type": .string("string"),
            "enum": .array(orderedPeriods.map { .string(name(for: $0)) }),
            "description": .string(
                "Which period to measure. Weeks run Monday to Sunday. Use \"custom\" "
                    + "together with start_date and end_date for anything else."
            ),
        ]),
        "start_date": .object([
            "type": .string("string"),
            "description": .string(
                "Inclusive start of the range as YYYY-MM-DD. Required when period is \"custom\", ignored otherwise."
            ),
        ]),
        "end_date": .object([
            "type": .string("string"),
            "description": .string(
                "Inclusive end of the range as YYYY-MM-DD. Required when period is \"custom\", ignored otherwise."
            ),
        ]),
    ]

    // MARK: - Resolution result

    /// A period that has been resolved to a concrete date range.
    struct Resolved {
        let period: ReportPeriod
        let start: Date
        let end: Date
        let calendar: Calendar
        /// Used as the end of still-running time entries.
        let now: Date

        /// The snake_case name to echo back to the caller.
        var name: String { MCPPeriodArgument.name(for: period) }

        /// A task's tracked time within this period.
        ///
        /// `.allTime` deliberately returns `task.totalTrackedTime` rather than aggregating
        /// over `distantPast…end of today`: that is the same number `list_tasks_and_tags`
        /// reports, so the two tools can never disagree about an all-time total, and it
        /// also counts a manual entry dated in the future, which a range never would.
        func trackedTime(for task: TaskItem) -> TimeInterval {
            guard period != .allTime else { return task.totalTrackedTime }
            return DailyTimeAggregator.total(
                for: task.timeEntries,
                rangeStart: start,
                rangeEnd: end,
                calendar: calendar,
                now: now
            )
        }

        /// `yyyy-MM-dd` range bounds for the response, or `nil` for `.allTime` — whose
        /// start is `Date.distantPast` and would only be noise.
        var formattedBounds: (start: String, end: String)? {
            guard period != .allTime else { return nil }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            return (formatter.string(from: start), formatter.string(from: end))
        }
    }

    // MARK: - Failures

    /// A malformed period argument. Unlike "no tasks matched", these really are caller
    /// errors, so the tools surface them as `isError` results — with a message naming the
    /// accepted values so the AI can fix the call on its next attempt.
    enum Failure: Error, Equatable {
        case missingPeriod
        case unknownPeriod(String)
        case missingCustomDates
        case unparsableDate(String)
        case invertedRange

        var message: String {
            switch self {
            case .missingPeriod:
                "Missing \"period\". Pass one of: \(Failure.allowedList)."
            case .unknownPeriod(let value):
                "Unknown period \"\(value)\". Pass one of: \(Failure.allowedList)."
            case .missingCustomDates:
                "period \"custom\" needs both start_date and end_date as YYYY-MM-DD."
            case .unparsableDate(let value):
                "Could not read the date \"\(value)\". Use the format YYYY-MM-DD, e.g. 2026-01-31."
            case .invertedRange:
                "end_date falls before start_date. Pass the earlier date as start_date."
            }
        }

        private static var allowedList: String {
            MCPPeriodArgument.orderedPeriods
                .map { "\"\(MCPPeriodArgument.name(for: $0))\"" }
                .joined(separator: ", ")
        }
    }

    // MARK: - Parsing

    /// - Parameter fallback: the period to use when no `period` argument was supplied.
    ///   `nil` makes the argument mandatory.
    static func resolve(
        arguments: [String: Value]?,
        fallback: ReportPeriod?,
        calendar: Calendar,
        now: Date
    ) -> Result<Resolved, Failure> {
        resolve(
            period: arguments?["period"]?.stringValue,
            startDate: arguments?["start_date"]?.stringValue,
            endDate: arguments?["end_date"]?.stringValue,
            fallback: fallback,
            calendar: calendar,
            now: now
        )
    }

    static func resolve(
        period rawPeriod: String?,
        startDate rawStart: String?,
        endDate rawEnd: String?,
        fallback: ReportPeriod?,
        calendar: Calendar,
        now: Date
    ) -> Result<Resolved, Failure> {
        let period: ReportPeriod

        if let rawPeriod, !rawPeriod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = self.period(named: rawPeriod) else {
                return .failure(.unknownPeriod(rawPeriod))
            }
            period = parsed
        } else if let fallback {
            period = fallback
        } else {
            return .failure(.missingPeriod)
        }

        guard period == .customRange else {
            let range = period.dateRange(calendar: calendar, now: now)
            return .success(
                Resolved(period: period, start: range.start, end: range.end, calendar: calendar, now: now)
            )
        }

        guard let rawStart, let rawEnd else { return .failure(.missingCustomDates) }
        guard let parsedStart = date(from: rawStart, calendar: calendar) else {
            return .failure(.unparsableDate(rawStart))
        }
        guard let parsedEnd = date(from: rawEnd, calendar: calendar) else {
            return .failure(.unparsableDate(rawEnd))
        }

        // Both bounds are inclusive days: the range runs from the first moment of
        // start_date to the last moment of end_date.
        let start = calendar.startOfDay(for: parsedStart)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: parsedEnd) ?? parsedEnd
        guard end > start else { return .failure(.invertedRange) }

        return .success(
            Resolved(period: period, start: start, end: end, calendar: calendar, now: now)
        )
    }

    /// Tolerant name matching — `this_month`, `this month`, `thisMonth` and the
    /// `ReportPeriod` display value "This Month" all resolve to the same case.
    static func period(named rawValue: String) -> ReportPeriod? {
        let normalized = normalize(rawValue)
        guard !normalized.isEmpty else { return nil }

        if let match = orderedPeriods.first(where: { normalize(name(for: $0)) == normalized }) {
            return match
        }
        return orderedPeriods.first { normalize($0.rawValue) == normalized }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { !$0.isWhitespace && $0 != "_" && $0 != "-" }
    }

    private static func date(from value: String, calendar: Calendar) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: trimmed) { return date }

        // A caller that sends a full timestamp shouldn't be turned away for it.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: trimmed)
    }
}
