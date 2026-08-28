import Foundation

final class DefaultReportBuilderService: ReportBuilderService {

    func buildReport(_ request: ReportRequest) -> ReportData {
        var summaries: [ReportTaskSummary] = []

        for task in request.tasks {
            // Splits entries that cross midnight across every day they span, rather than
            // attributing the whole entry to the day it started on. Same rule the Heatmap
            // uses, so per-day figures agree wherever they're shown.
            let dailyTotals = DailyTimeAggregator.dailyTotals(
                for: task.timeEntries,
                rangeStart: request.startDate,
                rangeEnd: request.endDate,
                calendar: request.calendar,
                now: request.now
            )

            let rawTime = dailyTotals.values.reduce(0, +)
            guard rawTime > 0 || request.includeZeroTime else { continue }

            let rate = task.hourlyRate ?? request.defaultHourlyRate
            let roundedTime = rawTime.rounded(to: request.rounding)

            let days = dailyTotals
                .sorted { $0.key < $1.key }
                .map { date, dayRawTime -> ReportDaySummary in
                    let dayRoundedTime = dayRawTime.rounded(to: request.rounding)
                    return ReportDaySummary(
                        date: date,
                        rawTime: dayRawTime,
                        roundedTime: dayRoundedTime,
                        amount: rate.map { dayRoundedTime / 3600.0 * $0 }
                    )
                }

            summaries.append(
                ReportTaskSummary(
                    id: task.id,
                    title: task.title,
                    rawTime: rawTime,
                    roundedTime: roundedTime,
                    hourlyRate: rate,
                    amount: rate.map { roundedTime / 3600.0 * $0 },
                    days: days
                )
            )
        }

        summaries.sort { $0.rawTime > $1.rawTime }

        let amounts = summaries.compactMap(\.amount)

        return ReportData(
            startDate: request.startDate,
            endDate: request.endDate,
            calendar: request.calendar,
            taskSummaries: summaries,
            defaultHourlyRate: request.defaultHourlyRate,
            totalRoundedTime: summaries.reduce(0) { $0 + $1.roundedTime },
            totalAmount: amounts.isEmpty ? nil : amounts.reduce(0, +),
            showAmountColumn: summaries.contains { $0.hourlyRate != nil }
        )
    }

    func makePDFConfig(for report: ReportData, presentation: ReportPresentation) -> ReportPDFConfig {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        dateFormatter.calendar = report.calendar
        dateFormatter.timeZone = report.calendar.timeZone

        var dayRows: [(date: Date, taskIndex: Int, row: ReportPDFTaskRow)] = []

        for (taskIndex, summary) in report.taskSummaries.enumerated() {
            for day in summary.days {
                dayRows.append((
                    date: day.date,
                    taskIndex: taskIndex,
                    row: ReportPDFTaskRow(
                        formattedDate: dateFormatter.string(from: day.date),
                        title: summary.title,
                        formattedTime: day.roundedTime.formattedHoursMinutes,
                        formattedAmount: day.amount.map {
                            CurrencyFormatting.amount($0, symbol: presentation.currencySymbol)
                        }
                    )
                ))
            }
        }

        // Chronological, with ties broken by the task's position in the report so the
        // same inputs always produce the same rows in the same order.
        dayRows.sort { lhs, rhs in
            lhs.date == rhs.date ? lhs.taskIndex < rhs.taskIndex : lhs.date < rhs.date
        }

        return ReportPDFConfig(
            businessName: presentation.businessName,
            startDate: report.startDate,
            endDate: report.endDate,
            generatedDate: presentation.generatedDate,
            tasks: dayRows.map(\.row),
            currencySymbol: presentation.currencySymbol,
            showAmountColumn: report.showAmountColumn,
            totalTime: report.totalRoundedTime.formattedHoursMinutes,
            totalAmount: report.totalAmount.map {
                CurrencyFormatting.amount($0, symbol: presentation.currencySymbol)
            },
            totalRate: report.defaultHourlyRate.map {
                CurrencyFormatting.rate($0, symbol: presentation.currencySymbol)
            }
        )
    }
}
