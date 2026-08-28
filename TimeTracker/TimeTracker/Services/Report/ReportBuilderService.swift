import Foundation

/// Everything needed to compute a report: the tasks to consider, the period, and the
/// preference values that drive rounding and rates. Deliberately a value type with no
/// UI or storage dependencies, so both the Report screen and headless callers can use it.
struct ReportRequest {
    let tasks: [TaskItem]
    let startDate: Date
    let endDate: Date
    let rounding: TimeRoundingInterval
    let defaultHourlyRate: Double?
    /// When false, tasks with no tracked time in the period are dropped.
    let includeZeroTime: Bool
    let calendar: Calendar
    /// Used as the end of still-running time entries.
    let now: Date

    init(
        tasks: [TaskItem],
        startDate: Date,
        endDate: Date,
        rounding: TimeRoundingInterval,
        defaultHourlyRate: Double?,
        includeZeroTime: Bool,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.tasks = tasks
        self.startDate = startDate
        self.endDate = endDate
        self.rounding = rounding
        self.defaultHourlyRate = defaultHourlyRate
        self.includeZeroTime = includeZeroTime
        self.calendar = calendar
        self.now = now
    }
}

extension ReportRequest {
    /// Convenience for callers that already hold a `UserPreferencesService`.
    init(
        tasks: [TaskItem],
        startDate: Date,
        endDate: Date,
        includeZeroTime: Bool,
        preferences: UserPreferencesService,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.init(
            tasks: tasks,
            startDate: startDate,
            endDate: endDate,
            rounding: TimeRoundingInterval(rawString: preferences.timeRounding),
            defaultHourlyRate: preferences.defaultHourlyRate,
            includeZeroTime: includeZeroTime,
            calendar: calendar,
            now: now
        )
    }
}

/// One calendar day's worth of a single task's tracked time.
struct ReportDaySummary {
    /// Start of the day, in the request's calendar.
    let date: Date
    let rawTime: TimeInterval
    let roundedTime: TimeInterval
    let amount: Double?
}

struct ReportTaskSummary: Identifiable {
    let id: UUID
    let title: String
    let rawTime: TimeInterval
    /// The task's whole-period raw time, rounded once. Note this is *not* the sum of
    /// `days.roundedTime` — see the note on `ReportData.totalRoundedTime`.
    let roundedTime: TimeInterval
    /// The task's own rate, falling back to the report's default rate.
    let hourlyRate: Double?
    let amount: Double?
    /// Ascending by date.
    let days: [ReportDaySummary]
}

struct ReportData {
    let startDate: Date
    let endDate: Date
    /// The calendar the day boundaries were computed in. Carried so that anything
    /// formatting `ReportDaySummary.date` renders the same day it was bucketed into.
    let calendar: Calendar
    /// Descending by `rawTime`.
    let taskSummaries: [ReportTaskSummary]
    /// Carried through so the PDF can render the "default rate" footer.
    let defaultHourlyRate: Double?
    /// The sum of each task's whole-period rounded time.
    ///
    /// This intentionally differs from the sum of the per-day rounded values shown as
    /// PDF rows: rounding applied once per task is not the same as rounding applied per
    /// day. Three 10-minute days at 15-minute rounding produce rows of 15m/15m/15m but a
    /// total of 30m. This is long-standing behavior of the Report screen and its export,
    /// preserved deliberately — do not "fix" it without deciding what it does to billing.
    let totalRoundedTime: TimeInterval
    let totalAmount: Double?
    let showAmountColumn: Bool
}

/// The display-only values a report needs before it can be rendered as a PDF.
struct ReportPresentation {
    let businessName: String
    let currencySymbol: String
    let generatedDate: Date
}

protocol ReportBuilderService: Sendable {
    func buildReport(_ request: ReportRequest) -> ReportData
    func makePDFConfig(for report: ReportData, presentation: ReportPresentation) -> ReportPDFConfig
}
