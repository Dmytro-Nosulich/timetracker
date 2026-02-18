import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class ReportViewModel {
    private let localStorageService: LocalStorageService
    private let userPreferencesService: UserPreferencesService
    private let pdfService: ReportPDFService

    var businessName: String = ""
    var selectedPeriod: ReportPeriod = .thisMonth {
        didSet {
            if selectedPeriod != .customRange {
                let range = selectedPeriod.dateRange()
                startDate = range.start
                endDate = range.end
            }
            recomputeRows()
        }
    }
    var startDate: Date = Date()
    var endDate: Date = Date()
    var includeZeroTime: Bool = false {
        didSet { recomputeRows() }
    }

    private(set) var taskRows: [ReportTaskRowItem] = []
    private var allTasks: [TaskItem] = []

    var showAmountColumn: Bool {
        taskRows.contains { $0.hourlyRate != nil }
    }

    var allSelected: Bool {
        get { !taskRows.isEmpty && taskRows.allSatisfy(\.isSelected) }
        set { setAllSelected(newValue) }
    }

    var totalSelectedTime: TimeInterval {
        taskRows.filter(\.isSelected).reduce(0) { $0 + $1.roundedTime }
    }

    var totalSelectedAmount: Double? {
        let selected = taskRows.filter(\.isSelected)
        let withAmount = selected.compactMap(\.amount)
        guard !withAmount.isEmpty else { return nil }
        return withAmount.reduce(0, +)
    }

    var currencySymbol: String {
        userPreferencesService.currencySymbol
    }

    private var roundingInterval: TimeRoundingInterval {
        TimeRoundingInterval(rawString: userPreferencesService.timeRounding)
    }

    init(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService,
        pdfService: ReportPDFService
    ) {
        self.localStorageService = localStorageService
        self.userPreferencesService = userPreferencesService
        self.pdfService = pdfService
    }

    func onAppear() {
        businessName = userPreferencesService.businessName

        let range = selectedPeriod.dateRange()
        startDate = range.start
        endDate = range.end

        loadTasks()
    }

    func loadTasks() {
        allTasks = localStorageService.fetchTasks()
        recomputeRows()
    }

    func onStartDateChanged() {
        if selectedPeriod != .customRange {
            selectedPeriod = .customRange
        } else {
            recomputeRows()
        }
    }

    func onEndDateChanged() {
        if selectedPeriod != .customRange {
            selectedPeriod = .customRange
        } else {
            recomputeRows()
        }
    }

    func toggleTask(_ id: UUID) {
        if let index = taskRows.firstIndex(where: { $0.id == id }) {
            taskRows[index].isSelected.toggle()
        }
    }

    func setAllSelected(_ value: Bool) {
        for i in taskRows.indices {
            taskRows[i].isSelected = value
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = selectedPeriod.defaultFilename(startDate: startDate, endDate: endDate) + ".pdf"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let selectedTasks = taskRows.filter(\.isSelected)
        let pdfRows = selectedTasks.map { row in
            ReportPDFTaskRow(
                title: row.title,
                formattedTime: row.roundedTime.formattedHoursMinutes,
                formattedRate: formattedRate(for: row),
                formattedAmount: formattedAmount(for: row)
            )
        }

        let showRate = selectedTasks.contains { $0.hourlyRate != nil }
        let totalTime = selectedTasks.reduce(0.0) { $0 + $1.roundedTime }
        let amounts = selectedTasks.compactMap(\.amount)
        let totalAmountValue: Double? = amounts.isEmpty ? nil : amounts.reduce(0, +)

        let config = ReportPDFConfig(
            businessName: businessName,
            startDate: startDate,
            endDate: endDate,
            generatedDate: Date(),
            tasks: pdfRows,
            currencySymbol: currencySymbol,
            showRateColumns: showRate,
            totalTime: totalTime.formattedHoursMinutes,
            totalAmount: totalAmountValue.map { formatCurrency($0) }
        )

        let data = pdfService.generatePDF(config: config)
        try? data.write(to: url)
    }

    // MARK: - Private

    private func recomputeRows() {
        let defaultRate = userPreferencesService.defaultHourlyRate
        let rounding = roundingInterval

        var rows = allTasks.map { task -> ReportTaskRowItem in
            let rawTime = trackedTime(for: task, from: startDate, to: endDate)
            let rounded = rawTime.rounded(to: rounding)
            let rate = task.hourlyRate ?? defaultRate
            let amount: Double? = rate.map { rounded / 3600.0 * $0 }

            return ReportTaskRowItem(
                id: task.id,
                title: task.title,
                timeForPeriod: rawTime,
                roundedTime: rounded,
                hourlyRate: rate,
                amount: amount,
                isSelected: true
            )
        }

        if !includeZeroTime {
            rows = rows.filter { $0.timeForPeriod > 0 }
        }

        rows.sort { $0.timeForPeriod > $1.timeForPeriod }

        let previousSelections = Set(taskRows.filter(\.isSelected).map(\.id))
        if !taskRows.isEmpty {
            for i in rows.indices {
                rows[i].isSelected = previousSelections.contains(rows[i].id)
            }
        }

        taskRows = rows
    }

    private func trackedTime(for task: TaskItem, from periodStart: Date, to periodEnd: Date) -> TimeInterval {
        task.timeEntries
            .filter { entry in
                let entryEnd = entry.endDate ?? Date()
                return entry.startDate < periodEnd && entryEnd > periodStart
            }
            .reduce(0) { total, entry in
                let effectiveStart = max(entry.startDate, periodStart)
                let effectiveEnd = min(entry.endDate ?? Date(), periodEnd)
                return total + max(0, effectiveEnd.timeIntervalSince(effectiveStart))
            }
    }

    func formattedRate(for row: ReportTaskRowItem) -> String? {
        guard let rate = row.hourlyRate else { return nil }
        return "\(currencySymbol)\(formatNumber(rate))/h"
    }

    func formattedAmount(for row: ReportTaskRowItem) -> String? {
        guard let amount = row.amount else { return nil }
        return formatCurrency(amount)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(currencySymbol)\(formatted)"
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
