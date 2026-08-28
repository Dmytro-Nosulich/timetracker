import Testing
import Foundation
@testable import TimeTracker

struct DefaultReportBuilderServiceTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func entry(start: Date, end: Date?) -> TimeEntryItem {
        TimeEntryItem(id: UUID(), startDate: start, endDate: end, isManual: false, note: nil)
    }

    private func task(
        id: UUID = UUID(),
        title: String = "Task",
        hourlyRate: Double? = nil,
        entries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: hourlyRate,
            tags: [],
            timeEntries: entries,
            totalTrackedTime: entries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    /// March 2026, unless a test needs otherwise.
    private func request(
        tasks: [TaskItem],
        start: Date? = nil,
        end: Date? = nil,
        rounding: TimeRoundingInterval = .none,
        defaultHourlyRate: Double? = nil,
        includeZeroTime: Bool = false,
        now: Date? = nil
    ) -> ReportRequest {
        ReportRequest(
            tasks: tasks,
            startDate: start ?? date(2026, 3, 1),
            endDate: end ?? date(2026, 4, 1),
            rounding: rounding,
            defaultHourlyRate: defaultHourlyRate,
            includeZeroTime: includeZeroTime,
            calendar: calendar,
            now: now ?? date(2026, 3, 15, 12)
        )
    }

    private func presentation(
        businessName: String = "Acme Corp",
        currencySymbol: String = "$",
        generatedDate: Date? = nil
    ) -> ReportPresentation {
        ReportPresentation(
            businessName: businessName,
            currencySymbol: currencySymbol,
            generatedDate: generatedDate ?? Date()
        )
    }

    private var sut: DefaultReportBuilderService { DefaultReportBuilderService() }

    // MARK: - Task totals

    @Test func sumsTrackedTimeWithinRange() {
        let t = task(entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12)),
            entry(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 11))
        ])
        let report = sut.buildReport(request(tasks: [t]))

        #expect(report.taskSummaries.count == 1)
        #expect(report.taskSummaries[0].rawTime == 5 * 3600)
    }

    @Test func excludesEntriesOutsideRange() {
        let t = task(entries: [
            entry(start: date(2026, 2, 15, 9), end: date(2026, 2, 15, 12)),
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 11))
        ])
        let report = sut.buildReport(request(tasks: [t]))

        #expect(report.taskSummaries[0].rawTime == 2 * 3600)
    }

    @Test func clipsEntriesAtRangeBoundaries() {
        let t = task(entries: [entry(start: date(2026, 2, 28, 22), end: date(2026, 3, 1, 2))])
        let report = sut.buildReport(request(tasks: [t]))

        #expect(report.taskSummaries[0].rawTime == 2 * 3600)
    }

    @Test func openEntryUsesRequestNow() {
        let t = task(entries: [entry(start: date(2026, 3, 15, 9), end: nil)])
        let report = sut.buildReport(request(tasks: [t], now: date(2026, 3, 15, 12)))

        #expect(report.taskSummaries[0].rawTime == 3 * 3600)
    }

    // MARK: - Midnight split

    @Test func entryCrossingMidnightIsSplitAcrossBothDays() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 1))])
        let report = sut.buildReport(request(tasks: [t]))
        let days = report.taskSummaries[0].days

        #expect(days.count == 2)
        #expect(days[0].date == date(2026, 3, 10))
        #expect(days[0].rawTime == 3600)
        #expect(days[1].date == date(2026, 3, 11))
        #expect(days[1].rawTime == 3600)
    }

    @Test func overnightEntryIsNeverAttributedOutsideTheReportRange() {
        // Jan 31 23:00 -> Feb 1 02:00, reported for February only. The 2h that fall
        // inside February must land on Feb 1, not on the entry's Jan 31 start day.
        let t = task(entries: [entry(start: date(2026, 1, 31, 23), end: date(2026, 2, 1, 2))])
        let report = sut.buildReport(
            request(tasks: [t], start: date(2026, 2, 1), end: date(2026, 3, 1))
        )
        let days = report.taskSummaries[0].days

        #expect(days.count == 1)
        #expect(days[0].date == date(2026, 2, 1))
        #expect(days[0].rawTime == 2 * 3600)
    }

    @Test func multiDayEntrySpansEveryDayItCovers() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 22), end: date(2026, 3, 13, 2))])
        let report = sut.buildReport(request(tasks: [t]))
        let days = report.taskSummaries[0].days

        #expect(days.map(\.date) == [
            date(2026, 3, 10), date(2026, 3, 11), date(2026, 3, 12), date(2026, 3, 13)
        ])
        #expect(days[1].rawTime == 24 * 3600)
    }

    @Test func daysAreAscendingByDate() {
        let t = task(entries: [
            entry(start: date(2026, 3, 20, 9), end: date(2026, 3, 20, 10)),
            entry(start: date(2026, 3, 5, 9), end: date(2026, 3, 5, 10)),
            entry(start: date(2026, 3, 12, 9), end: date(2026, 3, 12, 10))
        ])
        let report = sut.buildReport(request(tasks: [t]))

        #expect(report.taskSummaries[0].days.map(\.date) == [
            date(2026, 3, 5), date(2026, 3, 12), date(2026, 3, 20)
        ])
    }

    // MARK: - Rounding

    @Test func roundingNoneLeavesTimeUntouched() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10))])
        let report = sut.buildReport(request(tasks: [t], rounding: .none))

        #expect(report.taskSummaries[0].roundedTime == 600)
    }

    @Test func taskTotalIsRoundedOnceOverTheWholePeriod() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10))])
        let report = sut.buildReport(request(tasks: [t], rounding: .fifteenMinutes))

        #expect(report.taskSummaries[0].rawTime == 600)
        #expect(report.taskSummaries[0].roundedTime == 900)
    }

    @Test func eachDayIsRoundedIndependently() {
        let t = task(entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10)),
            entry(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 9, 10))
        ])
        let report = sut.buildReport(request(tasks: [t], rounding: .fifteenMinutes))

        #expect(report.taskSummaries[0].days.allSatisfy { $0.roundedTime == 900 })
    }

    @Test func dayRowsNeedNotSumToTheGrandTotal() {
        // Deliberate, long-standing behavior: rounding applied once per task is not the
        // same as rounding applied per day. Three 10-minute days at 15-minute rounding
        // print as 15m/15m/15m but total 30m. Pinned so it can't drift unnoticed.
        let t = task(entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10)),
            entry(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 9, 10)),
            entry(start: date(2026, 3, 12, 9), end: date(2026, 3, 12, 9, 10))
        ])
        let report = sut.buildReport(request(tasks: [t], rounding: .fifteenMinutes))
        let summary = report.taskSummaries[0]

        #expect(summary.days.reduce(0) { $0 + $1.roundedTime } == 45 * 60)
        #expect(report.totalRoundedTime == 30 * 60)
    }

    // MARK: - Hourly rates and amounts

    @Test func taskRateWinsOverDefaultRate() {
        let t = task(hourlyRate: 100, entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let report = sut.buildReport(request(tasks: [t], defaultHourlyRate: 50))

        #expect(report.taskSummaries[0].hourlyRate == 100)
        #expect(report.taskSummaries[0].amount == 100)
    }

    @Test func defaultRateAppliesWhenTaskHasNone() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 11))])
        let report = sut.buildReport(request(tasks: [t], defaultHourlyRate: 50))

        #expect(report.taskSummaries[0].hourlyRate == 50)
        #expect(report.taskSummaries[0].amount == 100)
    }

    @Test func amountIsNilWhenNoRateAvailable() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 11))])
        let report = sut.buildReport(request(tasks: [t]))

        #expect(report.taskSummaries[0].hourlyRate == nil)
        #expect(report.taskSummaries[0].amount == nil)
        #expect(report.totalAmount == nil)
        #expect(report.showAmountColumn == false)
    }

    @Test func amountsUseRoundedTimeNotRawTime() {
        let t = task(hourlyRate: 60, entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10))])
        let report = sut.buildReport(request(tasks: [t], rounding: .fifteenMinutes))

        // 15 rounded minutes at $60/h = $15, not 10 raw minutes at $10.
        #expect(report.taskSummaries[0].amount == 15)
    }

    @Test func showAmountColumnIsTrueWhenAnyTaskHasARate() {
        let withRate = task(title: "Billable", hourlyRate: 100, entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))
        ])
        let withoutRate = task(title: "Unbilled", entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))
        ])
        let report = sut.buildReport(request(tasks: [withRate, withoutRate]))

        #expect(report.showAmountColumn)
        #expect(report.totalAmount == 100)
    }

    // MARK: - Zero-time filtering

    @Test func zeroTimeTasksAreDroppedByDefault() {
        let busy = task(title: "Busy", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let idle = task(title: "Idle")
        let report = sut.buildReport(request(tasks: [busy, idle]))

        #expect(report.taskSummaries.map(\.title) == ["Busy"])
    }

    @Test func zeroTimeTasksAreKeptWhenRequested() {
        let busy = task(title: "Busy", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let idle = task(title: "Idle")
        let report = sut.buildReport(request(tasks: [busy, idle], includeZeroTime: true))

        #expect(report.taskSummaries.count == 2)
        #expect(report.taskSummaries[1].title == "Idle")
        #expect(report.taskSummaries[1].rawTime == 0)
        #expect(report.taskSummaries[1].days.isEmpty)
    }

    @Test func aKeptZeroTimeTaskStillContributesItsRate() {
        let idle = task(title: "Idle", hourlyRate: 100)
        let report = sut.buildReport(request(tasks: [idle], includeZeroTime: true))

        #expect(report.showAmountColumn)
        #expect(report.totalAmount == 0)
    }

    // MARK: - Sorting

    @Test func taskSummariesAreSortedByTimeDescending() {
        let small = task(title: "Small", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let large = task(title: "Large", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let medium = task(title: "Medium", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 11))])
        let report = sut.buildReport(request(tasks: [small, large, medium]))

        #expect(report.taskSummaries.map(\.title) == ["Large", "Medium", "Small"])
    }

    // MARK: - Preferences convenience init

    @Test func requestReadsRoundingAndRateFromPreferences() {
        let prefs = MockUserPreferencesService()
        prefs.stubbedTimeRounding = "15"
        prefs.stubbedDefaultHourlyRate = 75

        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10))])
        let report = sut.buildReport(
            ReportRequest(
                tasks: [t],
                startDate: date(2026, 3, 1),
                endDate: date(2026, 4, 1),
                includeZeroTime: false,
                preferences: prefs,
                calendar: calendar,
                now: date(2026, 3, 15, 12)
            )
        )

        #expect(report.taskSummaries[0].roundedTime == 900)
        #expect(report.taskSummaries[0].hourlyRate == 75)
        #expect(report.defaultHourlyRate == 75)
    }

    @Test func requestFallsBackToNoRoundingForUnknownPreferenceValue() {
        let prefs = MockUserPreferencesService()
        prefs.stubbedTimeRounding = "not-a-rounding"

        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 9, 10))])
        let report = sut.buildReport(
            ReportRequest(
                tasks: [t],
                startDate: date(2026, 3, 1),
                endDate: date(2026, 4, 1),
                includeZeroTime: false,
                preferences: prefs,
                calendar: calendar,
                now: date(2026, 3, 15, 12)
            )
        )

        #expect(report.taskSummaries[0].roundedTime == 600)
    }

    // MARK: - makePDFConfig

    @Test func pdfConfigCarriesPresentationValues() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let report = sut.buildReport(request(tasks: [t]))
        let generated = date(2026, 4, 1, 8)
        let config = sut.makePDFConfig(
            for: report,
            presentation: presentation(businessName: "Acme Corp", currencySymbol: "€", generatedDate: generated)
        )

        #expect(config.businessName == "Acme Corp")
        #expect(config.currencySymbol == "€")
        #expect(config.generatedDate == generated)
        #expect(config.startDate == date(2026, 3, 1))
        #expect(config.endDate == date(2026, 4, 1))
    }

    @Test func pdfRowsAreOneRowPerTaskPerDay() {
        let t = task(title: "Website", entries: [
            entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12)),
            entry(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 11))
        ])
        let report = sut.buildReport(request(tasks: [t]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.tasks.count == 2)
        #expect(config.tasks[0].formattedDate == "10.03.2026")
        #expect(config.tasks[0].title == "Website")
        #expect(config.tasks[0].formattedTime == "3h 00m")
        #expect(config.tasks[1].formattedDate == "11.03.2026")
        #expect(config.tasks[1].formattedTime == "2h 00m")
    }

    @Test func pdfRowsAreChronologicalAcrossTasks() {
        let a = task(title: "A", entries: [
            entry(start: date(2026, 3, 12, 9), end: date(2026, 3, 12, 14))
        ])
        let b = task(title: "B", entries: [
            entry(start: date(2026, 3, 5, 9), end: date(2026, 3, 5, 11)),
            entry(start: date(2026, 3, 20, 9), end: date(2026, 3, 20, 10))
        ])
        let report = sut.buildReport(request(tasks: [a, b]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.tasks.map(\.formattedDate) == ["05.03.2026", "12.03.2026", "20.03.2026"])
        #expect(config.tasks.map(\.title) == ["B", "A", "B"])
    }

    @Test func pdfRowsOnTheSameDayAreOrderedByReportPosition() {
        let small = task(title: "Small", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 10))])
        let large = task(title: "Large", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let report = sut.buildReport(request(tasks: [small, large]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        // Same day, so they follow the report's own order: longest first.
        #expect(config.tasks.map(\.title) == ["Large", "Small"])
    }

    @Test func pdfAmountsAreFormattedWithTheCurrencySymbol() {
        let t = task(hourlyRate: 100, entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let report = sut.buildReport(request(tasks: [t]))
        let config = sut.makePDFConfig(for: report, presentation: presentation(currencySymbol: "€"))

        // The decimal separator is locale-dependent, so compare against the shared
        // formatter rather than a literal — what matters here is the value and the symbol.
        #expect(config.showAmountColumn)
        #expect(config.tasks[0].formattedAmount == CurrencyFormatting.amount(300, symbol: "€"))
        #expect(config.totalAmount == CurrencyFormatting.amount(300, symbol: "€"))
        #expect(config.tasks[0].formattedAmount?.hasPrefix("€") == true)
    }

    @Test func pdfAmountsAreNilWithoutRates() {
        let t = task(entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let report = sut.buildReport(request(tasks: [t]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.showAmountColumn == false)
        #expect(config.tasks[0].formattedAmount == nil)
        #expect(config.totalAmount == nil)
    }

    @Test func pdfTotalRateComesFromTheDefaultRate() {
        let t = task(hourlyRate: 100, entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let report = sut.buildReport(request(tasks: [t], defaultHourlyRate: 50))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.totalRate == "$50/h")
    }

    @Test func pdfTotalRateIsNilWithoutADefaultRate() {
        let t = task(hourlyRate: 100, entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let report = sut.buildReport(request(tasks: [t]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.totalRate == nil)
    }

    @Test func pdfTotalTimeIsTheSumOfTaskTotals() {
        let a = task(title: "A", entries: [entry(start: date(2026, 3, 10, 9), end: date(2026, 3, 10, 12))])
        let b = task(title: "B", entries: [entry(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 11))])
        let report = sut.buildReport(request(tasks: [a, b]))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.totalTime == "5h 00m")
    }

    @Test func aSelectedZeroTimeTaskProducesNoRowsButStillCounts() {
        let idle = task(title: "Idle", hourlyRate: 100)
        let report = sut.buildReport(request(tasks: [idle], includeZeroTime: true))
        let config = sut.makePDFConfig(for: report, presentation: presentation())

        #expect(config.tasks.isEmpty)
        #expect(config.showAmountColumn)
        #expect(config.totalTime == "0h 00m")
    }

    // MARK: - Parity with the pre-refactor algorithm

    /// The day-grouping logic exactly as it was inline in `ReportViewModel.exportPDF()`
    /// before this service existed, so the refactor can be shown not to have moved any
    /// numbers for data that doesn't cross midnight.
    private func legacyPDFRows(
        tasks: [TaskItem],
        startDate: Date,
        endDate: Date,
        rounding: TimeRoundingInterval,
        defaultHourlyRate: Double?,
        currencySymbol: String,
        now: Date
    ) -> [ReportPDFTaskRow] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone

        var dayRows: [(date: Date, row: ReportPDFTaskRow)] = []

        for task in tasks {
            let rate = task.hourlyRate ?? defaultHourlyRate
            let relevantEntries = task.timeEntries.filter { entry in
                let entryEnd = entry.endDate ?? now
                return entry.startDate < endDate && entryEnd > startDate
            }

            var dayMap: [DateComponents: TimeInterval] = [:]
            for entry in relevantEntries {
                let effectiveStart = max(entry.startDate, startDate)
                let effectiveEnd = min(entry.endDate ?? now, endDate)
                guard effectiveEnd > effectiveStart else { continue }
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: entry.startDate)
                dayMap[dayComponents, default: 0] += effectiveEnd.timeIntervalSince(effectiveStart)
            }

            for (dayComponents, rawDayTime) in dayMap {
                let roundedDayTime = rawDayTime.rounded(to: rounding)
                let dayDate = calendar.date(from: dayComponents) ?? startDate
                let dayAmount: Double? = rate.map { roundedDayTime / 3600.0 * $0 }

                dayRows.append((
                    date: dayDate,
                    row: ReportPDFTaskRow(
                        formattedDate: dateFormatter.string(from: dayDate),
                        title: task.title,
                        formattedTime: roundedDayTime.formattedHoursMinutes,
                        formattedAmount: dayAmount.map { CurrencyFormatting.amount($0, symbol: currencySymbol) }
                    )
                ))
            }
        }

        dayRows.sort { $0.date < $1.date }
        return dayRows.map(\.row)
    }

    @Test func matchesTheLegacyAlgorithmForWorkThatDoesNotCrossMidnight() {
        let now = date(2026, 3, 31, 18)
        let tasks = [
            task(title: "Website", hourlyRate: 120, entries: [
                entry(start: date(2026, 3, 3, 9), end: date(2026, 3, 3, 12, 40)),
                entry(start: date(2026, 3, 3, 14), end: date(2026, 3, 3, 16)),
                entry(start: date(2026, 3, 17, 10), end: date(2026, 3, 17, 13, 25))
            ]),
            task(title: "Invoicing", entries: [
                entry(start: date(2026, 3, 9, 8, 15), end: date(2026, 3, 9, 9, 5)),
                entry(start: date(2026, 3, 24, 11), end: date(2026, 3, 24, 11, 50))
            ]),
            task(title: "Support", hourlyRate: 90, entries: [
                entry(start: date(2026, 3, 17, 15), end: date(2026, 3, 17, 17, 30))
            ])
        ]

        for rounding in TimeRoundingInterval.allCases {
            let report = sut.buildReport(
                request(tasks: tasks, rounding: rounding, defaultHourlyRate: 75, now: now)
            )
            let config = sut.makePDFConfig(
                for: report,
                presentation: presentation(currencySymbol: "$", generatedDate: now)
            )

            let legacy = legacyPDFRows(
                tasks: tasks,
                startDate: date(2026, 3, 1),
                endDate: date(2026, 4, 1),
                rounding: rounding,
                defaultHourlyRate: 75,
                currencySymbol: "$",
                now: now
            )

            #expect(config.tasks.count == legacy.count)
            // Row order for a given day was previously unspecified, so compare as sets.
            #expect(Set(config.tasks.map(\.formattedDate)) == Set(legacy.map(\.formattedDate)))
            for row in config.tasks {
                let match = legacy.first {
                    $0.formattedDate == row.formattedDate && $0.title == row.title
                }
                #expect(match?.formattedTime == row.formattedTime)
                #expect(match?.formattedAmount == row.formattedAmount)
            }
        }
    }

    @Test func divergesFromTheLegacyAlgorithmOnlyForOvernightWork() {
        let now = date(2026, 3, 31, 18)
        let tasks = [
            task(title: "Night shift", entries: [
                entry(start: date(2026, 3, 10, 22), end: date(2026, 3, 11, 2))
            ])
        ]
        let report = sut.buildReport(request(tasks: tasks, now: now))
        let config = sut.makePDFConfig(for: report, presentation: presentation(generatedDate: now))

        let legacy = legacyPDFRows(
            tasks: tasks,
            startDate: date(2026, 3, 1),
            endDate: date(2026, 4, 1),
            rounding: .none,
            defaultHourlyRate: nil,
            currencySymbol: "$",
            now: now
        )

        // Old: one 4h row on the start day. New: 2h on each of the two days worked.
        #expect(legacy.map(\.formattedDate) == ["10.03.2026"])
        #expect(legacy.map(\.formattedTime) == ["4h 00m"])
        #expect(config.tasks.map(\.formattedDate) == ["10.03.2026", "11.03.2026"])
        #expect(config.tasks.map(\.formattedTime) == ["2h 00m", "2h 00m"])
        // The task's grand total is untouched by the change.
        #expect(config.totalTime == "4h 00m")
    }
}
