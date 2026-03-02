import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct ReportViewModelTests {

    private func makeLocalStorage() -> MockLocalStorageService {
        MockLocalStorageService()
    }

    private func makePreferences() -> MockUserPreferencesService {
        MockUserPreferencesService()
    }

    private func makePDFService() -> MockReportPDFService {
        MockReportPDFService()
    }

    private func makeVM(
        localStorage: MockLocalStorageService? = nil,
        preferences: MockUserPreferencesService? = nil,
        pdfService: MockReportPDFService? = nil
    ) -> (ReportViewModel, MockLocalStorageService, MockUserPreferencesService, MockReportPDFService) {
        let ls = localStorage ?? makeLocalStorage()
        let prefs = preferences ?? makePreferences()
        let pdf = pdfService ?? makePDFService()
        let vm = ReportViewModel(
            localStorageService: ls,
            userPreferencesService: prefs,
            pdfService: pdf
        )
        return (vm, ls, prefs, pdf)
    }

    private func makeTask(
        id: UUID = UUID(),
        title: String = "Task",
        hourlyRate: Double? = nil,
        timeEntries: [TimeEntryItem] = []
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: hourlyRate,
            tags: [],
            timeEntries: timeEntries,
            totalTrackedTime: timeEntries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    private func makeTimeEntry(
        start: Date,
        end: Date?,
        isManual: Bool = false
    ) -> TimeEntryItem {
        TimeEntryItem(
            id: UUID(),
            startDate: start,
            endDate: end,
            isManual: isManual,
            note: nil
        )
    }

    // MARK: - onAppear

    @Test func onAppearLoadsPrefillBusinessName() {
        let (vm, _, prefs, _) = makeVM()
        prefs.stubbedBusinessName = "Acme Corp"
        vm.onAppear()
        #expect(vm.businessName == "Acme Corp")
    }

    @Test func onAppearSetsThisMonthAsDefault() {
        let (vm, _, _, _) = makeVM()
        vm.onAppear()
        #expect(vm.selectedPeriod == .thisMonth)
    }

    @Test func onAppearLoadsTasksWithNoEmptyRows() {
        let (vm, ls, _, _) = makeVM()
        ls.stubbedTasks = [makeTask(title: "A")]
        vm.onAppear()
        #expect(ls.fetchTasksCallCount == 1)
        #expect(vm.taskRows.count == 0)
    }

	@Test func onAppearLoadsTasksWithEmptyRows() {
		let (vm, ls, _, _) = makeVM()
		vm.includeZeroTime = true
		ls.stubbedTasks = [makeTask(title: "A")]
		vm.onAppear()
		#expect(ls.fetchTasksCallCount == 1)
		#expect(vm.taskRows.count == 1)
	}

    // MARK: - Task filtering (zero time)

    @Test func tasksWithZeroTimeHiddenByDefault() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -2, to: now)!,
            end: Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        )
        ls.stubbedTasks = [
            makeTask(title: "Has Time", timeEntries: [entry]),
            makeTask(title: "No Time", timeEntries: [])
        ]
        vm.onAppear()
        #expect(vm.taskRows.count == 1)
        #expect(vm.taskRows.first?.title == "Has Time")
    }

    @Test func includeZeroTimeShowsAll() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -2, to: now)!,
            end: Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        )
        ls.stubbedTasks = [
            makeTask(title: "Has Time", timeEntries: [entry]),
            makeTask(title: "No Time", timeEntries: [])
        ]
        vm.onAppear()
        vm.includeZeroTime = true
        #expect(vm.taskRows.count == 2)
    }

    // MARK: - Sorting

    @Test func tasksSortedByTimeDescending() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry1h = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        let entry3h = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -3, to: now)!,
            end: now
        )
        ls.stubbedTasks = [
            makeTask(title: "Small", timeEntries: [entry1h]),
            makeTask(title: "Large", timeEntries: [entry3h])
        ]
        vm.onAppear()
        #expect(vm.taskRows.first?.title == "Large")
        #expect(vm.taskRows.last?.title == "Small")
    }

    // MARK: - Selection

    @Test func allTasksSelectedByDefault() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(timeEntries: [entry])]
        vm.onAppear()
        let allSel = vm.taskRows.allSatisfy(\.isSelected)
        #expect(allSel)
        #expect(vm.allSelected == true)
    }

    @Test func toggleTaskDeselectsOne() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        let taskId = UUID()
        ls.stubbedTasks = [makeTask(id: taskId, timeEntries: [entry])]
        vm.onAppear()
        vm.toggleTask(taskId)
        #expect(vm.taskRows.first?.isSelected == false)
        #expect(vm.allSelected == false)
    }

    @Test func setAllSelectedSelectsAll() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        let id1 = UUID(), id2 = UUID()
        ls.stubbedTasks = [
            makeTask(id: id1, title: "A", timeEntries: [entry]),
            makeTask(id: id2, title: "B", timeEntries: [entry])
        ]
        vm.onAppear()
        vm.toggleTask(id1)
        vm.toggleTask(id2)
        let noneSelected = vm.taskRows.allSatisfy { !$0.isSelected }
        #expect(noneSelected)
        vm.setAllSelected(true)
        let allReselected = vm.taskRows.allSatisfy(\.isSelected)
        #expect(allReselected)
    }

    // MARK: - Amount column visibility

    @Test func showAmountColumnWhenTaskHasRate() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(hourlyRate: 50, timeEntries: [entry])]
        vm.onAppear()
        #expect(vm.showAmountColumn == true)
    }

    @Test func showAmountColumnWhenDefaultRateSet() {
        let (vm, ls, prefs, _) = makeVM()
        prefs.stubbedDefaultHourlyRate = 75
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(timeEntries: [entry])]
        vm.onAppear()
        #expect(vm.showAmountColumn == true)
    }

    @Test func hideAmountColumnWhenNoRates() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(timeEntries: [entry])]
        vm.onAppear()
        #expect(vm.showAmountColumn == false)
    }

    // MARK: - Totals

    @Test func totalSelectedTimeSumsCheckedTasks() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry1h = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        let entry2h = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -2, to: now)!,
            end: now
        )
        let id1 = UUID(), id2 = UUID()
        ls.stubbedTasks = [
            makeTask(id: id1, title: "A", timeEntries: [entry1h]),
            makeTask(id: id2, title: "B", timeEntries: [entry2h])
        ]
        vm.onAppear()
        let total = vm.totalSelectedTime
        #expect(total > 0)
        // Both selected by default, total should be ~3h
        #expect(abs(total - 3 * 3600) < 60)
    }

    @Test func totalSelectedAmountSumsOnlyTasksWithRates() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry1h = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [
            makeTask(title: "With Rate", hourlyRate: 100, timeEntries: [entry1h]),
            makeTask(title: "No Rate", timeEntries: [entry1h])
        ]
        vm.onAppear()
        let amount = vm.totalSelectedAmount
        #expect(amount != nil)
        // ~1h * $100 = $100
        #expect(abs(amount! - 100) < 2)
    }

    @Test func totalSelectedAmountNilWhenNoRates() {
        let (vm, ls, _, _) = makeVM()
        let now = Date()
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(timeEntries: [entry])]
        vm.onAppear()
        #expect(vm.totalSelectedAmount == nil)
    }

    // MARK: - Time rounding

    @Test func timeRoundingAppliedToRows() {
        let (vm, ls, prefs, _) = makeVM()
        prefs.stubbedTimeRounding = "15"
        let now = Date()
        // 7 min entry -> rounds to 0 with 15-min rounding
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .minute, value: -7, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(timeEntries: [entry])]
        vm.includeZeroTime = true
        vm.onAppear()
        let row = vm.taskRows.first
        #expect(row != nil)
        #expect(row!.roundedTime == 0)
    }

    @Test func timeRoundingAppliedToAmount() {
        let (vm, ls, prefs, _) = makeVM()
        prefs.stubbedTimeRounding = "30"
        let now = Date()
        // 20 min entry -> rounds to 30 min with 30-min rounding
        let entry = makeTimeEntry(
            start: Calendar.current.date(byAdding: .minute, value: -20, to: now)!,
            end: now
        )
        ls.stubbedTasks = [makeTask(hourlyRate: 60, timeEntries: [entry])]
        vm.onAppear()
        let row = vm.taskRows.first
        #expect(row != nil)
        // 30 min = 0.5h * $60 = $30
        #expect(abs(row!.amount! - 30) < 1)
    }

    // MARK: - Period changes

    @Test func changingPeriodUpdatesDates() {
        let (vm, ls, _, _) = makeVM()
        ls.stubbedTasks = []
        vm.onAppear()
        let initialStart = vm.startDate
        vm.selectedPeriod = .lastMonth
        #expect(vm.startDate != initialStart)
    }

    @Test func manualDateChangeSwitchesToCustomRange() {
        let (vm, _, _, _) = makeVM()
        vm.onAppear()
        #expect(vm.selectedPeriod == .thisMonth)
        vm.startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        vm.onStartDateChanged()
        #expect(vm.selectedPeriod == .customRange)
    }

    @Test func manualEndDateChangeSwitchesToCustomRange() {
        let (vm, _, _, _) = makeVM()
        vm.onAppear()
        #expect(vm.selectedPeriod == .thisMonth)
        vm.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        vm.onEndDateChanged()
        #expect(vm.selectedPeriod == .customRange)
    }

    // MARK: - Period time calculation

    @Test func onlyCountsTimeWithinPeriod() {
        let (vm, ls, _, _) = makeVM()
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let firstOfMonth = calendar.date(from: components)!

        // Entry starting before the period
        let entryBeforePeriod = makeTimeEntry(
            start: calendar.date(byAdding: .month, value: -2, to: firstOfMonth)!,
            end: calendar.date(byAdding: .month, value: -1, to: firstOfMonth)!
        )
        // Entry within the period
        let entryInPeriod = makeTimeEntry(
            start: calendar.date(byAdding: .day, value: 1, to: firstOfMonth)!,
            end: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 2, to: firstOfMonth)!)!
        )

        ls.stubbedTasks = [makeTask(timeEntries: [entryBeforePeriod, entryInPeriod])]
        vm.onAppear()

        #expect(vm.taskRows.count == 1)
        let row = vm.taskRows.first!
        // Only the in-period entry should count (~2h)
        #expect(row.timeForPeriod > 0)
        #expect(row.timeForPeriod < 3 * 3600)
    }

    // MARK: - Currency

    @Test func currencySymbolFromPreferences() {
        let (vm, _, prefs, _) = makeVM()
        prefs.stubbedCurrencySymbol = "€"
        #expect(vm.currencySymbol == "€")
    }

    // MARK: - Format helpers

    @Test func formatCurrencyFormatsCorrectly() {
        let (vm, _, prefs, _) = makeVM()
        prefs.stubbedCurrencySymbol = "$"
        let result = vm.formatCurrency(1225.50)
        #expect(result == "$1,225,50")
    }

    @Test func formattedRateReturnsNilWhenNoRate() {
        let (vm, _, _, _) = makeVM()
        let row = ReportTaskRowItem(
            id: UUID(), title: "T", timeForPeriod: 3600, roundedTime: 3600,
            hourlyRate: nil, amount: nil, isSelected: true
        )
        #expect(vm.formattedRate(for: row) == nil)
    }

    @Test func formattedRateFormatsWhenRatePresent() {
        let (vm, _, prefs, _) = makeVM()
        prefs.stubbedCurrencySymbol = "$"
        let row = ReportTaskRowItem(
            id: UUID(), title: "T", timeForPeriod: 3600, roundedTime: 3600,
            hourlyRate: 50, amount: 50, isSelected: true
        )
        let result = vm.formattedRate(for: row)
        #expect(result == "$50/h")
    }
}
