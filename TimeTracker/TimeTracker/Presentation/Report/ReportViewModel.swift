import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class ReportViewModel {
    private let localStorageService: LocalStorageService
    private let userPreferencesService: UserPreferencesService
    private let pdfService: ReportPDFService
    private let reportBuilder: ReportBuilderService

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
    private(set) var startDate: Date = Date()
    private(set) var endDate: Date = Date()
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

    init(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService,
        pdfService: ReportPDFService,
        reportBuilder: ReportBuilderService
    ) {
        self.localStorageService = localStorageService
        self.userPreferencesService = userPreferencesService
        self.pdfService = pdfService
        self.reportBuilder = reportBuilder

        let range = selectedPeriod.dateRange()
        startDate = range.start
        endDate = range.end
    }

    func onAppear() {
        businessName = userPreferencesService.businessName

        if selectedPeriod != .customRange {
            let range = selectedPeriod.dateRange()
            startDate = range.start
            endDate = range.end
        }

        loadTasks()
    }

    func loadTasks() {
        allTasks = localStorageService.fetchTasks()
        recomputeRows()
    }

    func setStartDate(_ date: Date) {
        guard date != startDate else { return }
        startDate = date
        switchToCustomRange()
    }

    func setEndDate(_ date: Date) {
        guard date != endDate else { return }
        endDate = date
        switchToCustomRange()
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

        let config = reportBuilder.makePDFConfig(
            for: buildReport(tasks: selectedTasks(), includeZeroTime: true),
            presentation: ReportPresentation(
                businessName: businessName,
                currencySymbol: currencySymbol,
                generatedDate: Date()
            )
        )

        let data = pdfService.generatePDF(config: config)
        try? data.write(to: url)
    }

    // MARK: - Private

    private func switchToCustomRange() {
        if selectedPeriod != .customRange {
            selectedPeriod = .customRange // didSet recomputes, and leaves the dates alone
        } else {
            recomputeRows()
        }
    }

    private func buildReport(tasks: [TaskItem], includeZeroTime: Bool) -> ReportData {
        reportBuilder.buildReport(
            ReportRequest(
                tasks: tasks,
                startDate: startDate,
                endDate: endDate,
                includeZeroTime: includeZeroTime,
                preferences: userPreferencesService
            )
        )
    }

    /// The tasks behind the currently ticked rows, in their underlying storage order.
    private func selectedTasks() -> [TaskItem] {
        let selectedIds = Set(taskRows.filter(\.isSelected).map(\.id))
        return allTasks.filter { selectedIds.contains($0.id) }
    }

    private func recomputeRows() {
        let report = buildReport(tasks: allTasks, includeZeroTime: includeZeroTime)

        var rows = report.taskSummaries.map { summary in
            ReportTaskRowItem(
                id: summary.id,
                title: summary.title,
                timeForPeriod: summary.rawTime,
                roundedTime: summary.roundedTime,
                hourlyRate: summary.hourlyRate,
                amount: summary.amount,
                isSelected: true
            )
        }

        let previousSelections = Set(taskRows.filter(\.isSelected).map(\.id))
        if !taskRows.isEmpty {
            for i in rows.indices {
                rows[i].isSelected = previousSelections.contains(rows[i].id)
            }
        }

        taskRows = rows
    }

    func formattedRate(for row: ReportTaskRowItem) -> String? {
        guard let rate = row.hourlyRate else { return nil }
        return CurrencyFormatting.rate(rate, symbol: currencySymbol)
    }

    func formattedAmount(for row: ReportTaskRowItem) -> String? {
        guard let amount = row.amount else { return nil }
        return formatCurrency(amount)
    }

    func formatCurrency(_ value: Double) -> String {
        CurrencyFormatting.amount(value, symbol: currencySymbol)
    }
}
