import Foundation

@Observable
@MainActor
final class HeatmapViewModel {
    private let localStorageService: LocalStorageService
    private let userPreferencesService: UserPreferencesService
    private let calendar = Calendar.current

    private var allTasks: [TaskItem] = []
    private(set) var dailyTotals: [Date: TimeInterval] = [:]
    private(set) var earliestEntryMonth: Date?
    private(set) var latestEntryMonth: Date?
    private(set) var selectedDate: Date?
    private(set) var selectedDayTaskRows: [SelectedDayTaskRow] = []

    var displayMonth: Date = Date()

    var hasAnyEntries: Bool { earliestEntryMonth != nil }

    var canNavigateBackward: Bool {
        guard let earliest = earliestEntryMonth else { return false }
        return displayMonth > earliest
    }

    var canNavigateForward: Bool {
        guard let latest = latestEntryMonth else { return false }
        return displayMonth < latest
    }

    var availableYears: [Int] {
        guard let earliest = earliestEntryMonth, let latest = latestEntryMonth else { return [] }
        return Array(calendar.component(.year, from: earliest)...calendar.component(.year, from: latest))
    }

    var availableMonthsForDisplayedYear: [Int] {
        guard let earliest = earliestEntryMonth, let latest = latestEntryMonth else { return [] }
        let year = calendar.component(.year, from: displayMonth)
        let lowerBound = year == calendar.component(.year, from: earliest) ? calendar.component(.month, from: earliest) : 1
        let upperBound = year == calendar.component(.year, from: latest) ? calendar.component(.month, from: latest) : 12
        return Array(lowerBound...upperBound)
    }

    var targetDailyHours: TimeInterval {
        userPreferencesService.targetDailyHours
    }

    init(localStorageService: LocalStorageService, userPreferencesService: UserPreferencesService) {
        self.localStorageService = localStorageService
        self.userPreferencesService = userPreferencesService
    }

    func onAppear() {
        allTasks = localStorageService.fetchTasks()
        computeBounds()
        displayMonth = defaultDisplayMonth()
        recomputeDailyTotals()
    }

    func hoursForDay(_ date: Date) -> TimeInterval {
        dailyTotals[calendar.startOfDay(for: date)] ?? 0
    }

    func selectDay(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        if selectedDate == dayStart {
            selectedDate = nil
            selectedDayTaskRows = []
            return
        }
        selectedDate = dayStart
        selectedDayTaskRows = taskRows(for: dayStart)
    }

    var monthTotal: TimeInterval {
        dailyTotals.values.reduce(0, +)
    }

    var isCurrentMonthAvailable: Bool {
        monthHasEntries(startOfMonth(Date()))
    }

    func jumpToToday() {
        let now = Date()
        setDisplayMonth(year: calendar.component(.year, from: now), month: calendar.component(.month, from: now))
    }

    func navigateMonth(by delta: Int) {
        guard let candidate = calendar.date(byAdding: .month, value: delta, to: displayMonth),
              let earliest = earliestEntryMonth, let latest = latestEntryMonth else { return }
        changeDisplayMonth(to: min(max(candidate, earliest), latest))
    }

    func setDisplayMonth(year: Int, month: Int) {
        guard let earliest = earliestEntryMonth, let latest = latestEntryMonth else { return }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let candidate = calendar.date(from: components) else { return }
        changeDisplayMonth(to: min(max(candidate, earliest), latest))
    }

    // MARK: - Private

    private func changeDisplayMonth(to newMonth: Date) {
        displayMonth = newMonth
        selectedDate = nil
        selectedDayTaskRows = []
        recomputeDailyTotals()
    }

    private func taskRows(for dayStart: Date) -> [SelectedDayTaskRow] {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return allTasks.compactMap { task -> SelectedDayTaskRow? in
            let totals = DailyTimeAggregator.dailyTotals(
                for: task.timeEntries,
                rangeStart: dayStart,
                rangeEnd: dayEnd,
                calendar: calendar
            )
            let duration = totals.values.reduce(0, +)
            guard duration > 0 else { return nil }
            return SelectedDayTaskRow(id: task.id, title: task.title, tags: task.tags, duration: duration)
        }.sorted { $0.duration > $1.duration }
    }

    private func computeBounds() {
        let allEntries = allTasks.flatMap(\.timeEntries)
        guard let earliestDate = allEntries.map(\.startDate).min(),
              let latestDate = allEntries.map({ $0.endDate ?? Date() }).max() else {
            earliestEntryMonth = nil
            latestEntryMonth = nil
            return
        }
        earliestEntryMonth = startOfMonth(earliestDate)
        latestEntryMonth = startOfMonth(latestDate)
    }

    private func defaultDisplayMonth() -> Date {
        let currentMonth = startOfMonth(Date())
        return monthHasEntries(currentMonth) ? currentMonth : (latestEntryMonth ?? currentMonth)
    }

    private func monthHasEntries(_ month: Date) -> Bool {
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: month) else { return false }
        return allTasks.flatMap(\.timeEntries).contains { entry in
            let entryEnd = entry.endDate ?? Date()
            return entry.startDate < monthEnd && entryEnd > month
        }
    }

    private func recomputeDailyTotals() {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            dailyTotals = [:]
            return
        }
        dailyTotals = DailyTimeAggregator.dailyTotals(
            for: allTasks.flatMap(\.timeEntries),
            rangeStart: monthStart,
            rangeEnd: monthEnd,
            calendar: calendar
        )
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
