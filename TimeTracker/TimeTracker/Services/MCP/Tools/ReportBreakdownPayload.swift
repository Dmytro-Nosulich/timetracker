import Foundation

/// The JSON body returned by `get_billable_report`.
///
/// Every figure here comes straight off `ReportData` — nothing is recomputed, so the
/// numbers are the same ones the Report screen renders and the PDF prints. Money appears
/// twice on purpose: the exact `Double` behind the calculation, and the string
/// `CurrencyFormatting` produces, which is the string the PDF shows.
struct ReportBreakdownPayload: Encodable, Equatable {

    struct Day: Encodable, Equatable {
        let date: String
        let rawTimeSeconds: Int
        let roundedTimeSeconds: Int
        let roundedTimeFormatted: String
        let amount: Double?
        let amountFormatted: String?
    }

    struct Task: Encodable, Equatable {
        let id: String
        let title: String
        /// Tracked time before rounding — the same figure `get_time_for_period` reports for
        /// this task, so the two tools can be reconciled against each other.
        let rawTimeSeconds: Int
        let rawTimeFormatted: String
        /// The billable figure: the whole period's raw time, rounded once.
        let roundedTimeSeconds: Int
        let roundedTimeFormatted: String
        /// The task's own rate, or the default rate when it has none. Absent when neither
        /// exists, in which case there is no amount either.
        let hourlyRate: Double?
        let hourlyRateFormatted: String?
        let amount: Double?
        let amountFormatted: String?
        /// Present only when `include_daily_breakdown` was set.
        let days: [Day]?
    }

    let period: String
    let startDate: String?
    let endDate: String?
    let businessName: String?
    let currencySymbol: String
    /// The rounding actually applied, in minutes. `0` means no rounding, so the caller can
    /// say what was done to the numbers rather than guessing.
    let roundingMinutes: Int
    let defaultHourlyRate: Double?
    let defaultHourlyRateFormatted: String?
    /// False when no task and no default carries a rate — then every amount is absent.
    let showAmountColumn: Bool
    let taskCount: Int
    let tasks: [Task]
    /// The sum of every task's rounded time, truncated to whole seconds once — exactly as
    /// the Report screen's footer computes it.
    ///
    /// Adding up the per-task `roundedTimeSeconds` can come out a few seconds short: each
    /// row drops its own sub-second fraction, while this drops one fraction over the whole
    /// sum. The Report screen behaves the same way (it truncates each row to whole minutes
    /// for display), and matching the screen is what this tool is for, so the dust is left
    /// alone and `note` tells the caller not to re-add the rows.
    let totalRoundedTimeSeconds: Int
    let totalRoundedTimeFormatted: String
    let totalAmount: Double?
    let totalAmountFormatted: String?
    /// Always present: how to read the totals, plus the per-day caveat when `days` is here.
    let note: String
}

/// Turns a computed `ReportData` into the tool's JSON payload. Pure — no storage, no MCP,
/// and deliberately no arithmetic beyond converting seconds to `Int` for printing.
enum ReportBreakdownPayloadBuilder {

    /// Every total here is computed over a whole period in one go, so re-deriving it by
    /// adding rows up gives a slightly different answer. The caller needs telling, or it
    /// will "correct" a total that is in fact the one on the user's invoice.
    static let totalsNote = """
        Report the totals as given. They are computed over each task's whole period at once, \
        so adding up the per-task seconds can differ by a few seconds from \
        totalRoundedTimeSeconds.
        """

    /// Day rows are rounded per day while the total rounds each task's whole period once,
    /// so three 10-minute days at 15-minute rounding print as 15m/15m/15m but total 30m.
    /// That is long-standing Report-screen behavior, and the gap it opens is minutes rather
    /// than seconds.
    static let dailyBreakdownNote = """
        Day rows are rounded per day, while each task's total rounds its whole-period time \
        once, so the day rows need not add up to the task total either.
        """

    static func build(
        report: ReportData,
        period: MCPPeriodArgument.Resolved,
        preferences: ReportBreakdownPreferences,
        includeDailyBreakdown: Bool
    ) -> ReportBreakdownPayload {
        let symbol = preferences.currencySymbol
        let dayFormatter = dayFormatter(calendar: report.calendar)
        let bounds = period.formattedBounds

        let tasks = report.taskSummaries.map { summary in
            ReportBreakdownPayload.Task(
                id: summary.id.uuidString,
                title: summary.title,
                rawTimeSeconds: Int(summary.rawTime),
                rawTimeFormatted: summary.rawTime.formattedHoursMinutes,
                roundedTimeSeconds: Int(summary.roundedTime),
                roundedTimeFormatted: summary.roundedTime.formattedHoursMinutes,
                hourlyRate: summary.hourlyRate,
                hourlyRateFormatted: summary.hourlyRate.map {
                    CurrencyFormatting.rate($0, symbol: symbol)
                },
                amount: summary.amount,
                amountFormatted: summary.amount.map {
                    CurrencyFormatting.amount($0, symbol: symbol)
                },
                days: includeDailyBreakdown
                    ? summary.days.map { day in
                        ReportBreakdownPayload.Day(
                            date: dayFormatter.string(from: day.date),
                            rawTimeSeconds: Int(day.rawTime),
                            roundedTimeSeconds: Int(day.roundedTime),
                            roundedTimeFormatted: day.roundedTime.formattedHoursMinutes,
                            amount: day.amount,
                            amountFormatted: day.amount.map {
                                CurrencyFormatting.amount($0, symbol: symbol)
                            }
                        )
                    }
                    : nil
            )
        }

        let businessName = preferences.businessName.trimmingCharacters(in: .whitespacesAndNewlines)

        return ReportBreakdownPayload(
            period: period.name,
            startDate: bounds?.start,
            endDate: bounds?.end,
            businessName: businessName.isEmpty ? nil : businessName,
            currencySymbol: symbol,
            roundingMinutes: Int(preferences.rounding.seconds) / 60,
            defaultHourlyRate: report.defaultHourlyRate,
            defaultHourlyRateFormatted: report.defaultHourlyRate.map {
                CurrencyFormatting.rate($0, symbol: symbol)
            },
            showAmountColumn: report.showAmountColumn,
            taskCount: tasks.count,
            tasks: tasks,
            totalRoundedTimeSeconds: Int(report.totalRoundedTime),
            totalRoundedTimeFormatted: report.totalRoundedTime.formattedHoursMinutes,
            totalAmount: report.totalAmount,
            totalAmountFormatted: report.totalAmount.map {
                CurrencyFormatting.amount($0, symbol: symbol)
            },
            note: includeDailyBreakdown ? "\(totalsNote) \(dailyBreakdownNote)" : totalsNote
        )
    }

    /// Formats day buckets in the calendar they were bucketed into, the same way
    /// `makePDFConfig` does, so a day row can never be stamped with a neighbouring date.
    private static func dayFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

/// The preference values the report payload needs, snapshotted so the builder stays pure.
struct ReportBreakdownPreferences: Sendable, Equatable {
    let rounding: TimeRoundingInterval
    let currencySymbol: String
    let businessName: String

    init(rounding: TimeRoundingInterval, currencySymbol: String, businessName: String) {
        self.rounding = rounding
        self.currencySymbol = currencySymbol
        self.businessName = businessName
    }

    /// Read fresh on every tool call, never cached — the user can change rounding, their
    /// currency or their business name in Settings while the server is running.
    init(preferences: any UserPreferencesService) {
        self.init(
            rounding: TimeRoundingInterval(rawString: preferences.timeRounding),
            currencySymbol: preferences.currencySymbol,
            businessName: preferences.businessName
        )
    }
}
