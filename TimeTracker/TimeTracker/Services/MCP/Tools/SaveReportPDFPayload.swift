import Foundation

/// The JSON body returned by `save_report_pdf`.
///
/// `path` is the whole point: it is where the file actually landed, which is not
/// necessarily where the caller asked for it (see `renamedToAvoidOverwrite`). The report
/// figures are carried too, in the formatted form the PDF itself prints, so the caller can
/// summarise what it produced without a second `get_billable_report` call.
struct SaveReportPDFPayload: Encodable, Equatable {
    /// Absolute path of the file that was written.
    let path: String
    let filename: String
    let directory: String
    /// True when something was already at the requested name and the file was written as
    /// "… (2).pdf" instead. Nothing is ever overwritten.
    let renamedToAvoidOverwrite: Bool
    /// Only present when the name changed — the name the file would have had.
    let requestedFilename: String?

    let period: String
    /// Omitted for `all_time`, as in the other tools.
    let startDate: String?
    let endDate: String?
    /// Echoed when a task filter narrowed the report, so the caller can state what the
    /// PDF actually covers rather than implying it covers everything.
    let taskQuery: String?

    /// How many tasks made it into the report.
    let taskCount: Int
    /// The totals the PDF prints, formatted identically to it.
    let totalRoundedTimeFormatted: String
    let totalAmountFormatted: String?

    let fileSizeBytes: Int
    let note: String
}

/// Turns a written report into the tool's JSON payload. Pure — no filesystem, no MCP.
enum SaveReportPDFPayloadBuilder {

    static let note = """
        The PDF has been saved. Report the path exactly as given — it is where the file \
        actually is, which may differ from the requested name if something was already there.
        """

    static func build(
        destination: ReportPDFDestination.Resolved,
        report: ReportData,
        period: MCPPeriodArgument.Resolved,
        currencySymbol: String,
        taskQuery: String?,
        fileSizeBytes: Int
    ) -> SaveReportPDFPayload {
        let bounds = period.formattedBounds

        return SaveReportPDFPayload(
            path: destination.url.path,
            filename: destination.filename,
            directory: destination.directory,
            renamedToAvoidOverwrite: destination.renamedToAvoidOverwrite,
            requestedFilename: destination.renamedToAvoidOverwrite ? destination.requestedFilename : nil,
            period: period.name,
            startDate: bounds?.start,
            endDate: bounds?.end,
            taskQuery: taskQuery,
            taskCount: report.taskSummaries.count,
            totalRoundedTimeFormatted: report.totalRoundedTime.formattedHoursMinutes,
            totalAmountFormatted: report.totalAmount.map {
                CurrencyFormatting.amount($0, symbol: currencySymbol)
            },
            fileSizeBytes: fileSizeBytes,
            note: note
        )
    }
}
