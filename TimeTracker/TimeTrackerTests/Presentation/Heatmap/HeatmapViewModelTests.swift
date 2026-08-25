import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct HeatmapViewModelTests {

    private let calendar = Calendar.current

    private func makeVM(tasks: [TaskItem] = []) -> (HeatmapViewModel, MockLocalStorageService, MockUserPreferencesService) {
        let ls = MockLocalStorageService()
        ls.stubbedTasks = tasks
        let prefs = MockUserPreferencesService()
        let vm = HeatmapViewModel(localStorageService: ls, userPreferencesService: prefs)
        return (vm, ls, prefs)
    }

    private func makeTask(timeEntries: [TimeEntryItem]) -> TaskItem {
        TaskItem(
            id: UUID(),
            title: "Task",
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: timeEntries,
            totalTrackedTime: timeEntries.reduce(0) { $0 + $1.duration },
            trackedTimeToday: 0
        )
    }

    private func entry(start: Date, end: Date?) -> TimeEntryItem {
        TimeEntryItem(id: UUID(), startDate: start, endDate: end, isManual: false, note: nil)
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    private func monthsAgo(_ n: Int, from date: Date = Date()) -> Date {
        calendar.date(byAdding: .month, value: -n, to: date)!
    }

    // MARK: - Target daily hours

    @Test func targetDailyHoursReadsThroughFromPreferences() {
        let (vm, _, prefs) = makeVM()
        prefs.stubbedTargetDailyHours = 6 * 3600
        #expect(vm.targetDailyHours == prefs.stubbedTargetDailyHours)
    }

    // MARK: - Empty state

    @Test func onAppearWithNoEntriesHasNoEntries() {
        let (vm, _, _) = makeVM()
        vm.onAppear()
        #expect(vm.hasAnyEntries == false)
        #expect(vm.canNavigateBackward == false)
        #expect(vm.canNavigateForward == false)
    }

    // MARK: - Default month

    @Test func defaultsToCurrentMonthWhenCurrentMonthHasEntries() {
        let now = Date()
        let task = makeTask(timeEntries: [entry(start: now, end: now.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        #expect(calendar.isDate(vm.displayMonth, equalTo: now, toGranularity: .month))
    }

    @Test func defaultsToLatestEntryMonthWhenCurrentMonthHasNoEntries() {
        let pastDate = monthsAgo(3)
        let task = makeTask(timeEntries: [entry(start: pastDate, end: pastDate.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        #expect(calendar.isDate(vm.displayMonth, equalTo: pastDate, toGranularity: .month))
    }

    // MARK: - Bounds

    @Test func earliestAndLatestMonthsComputedAcrossAllTasks() {
        let earliest = monthsAgo(5)
        let latest = monthsAgo(1)
        let taskA = makeTask(timeEntries: [entry(start: earliest, end: earliest.addingTimeInterval(3600))])
        let taskB = makeTask(timeEntries: [entry(start: latest, end: latest.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [taskA, taskB])
        vm.onAppear()
        #expect(vm.earliestEntryMonth == startOfMonth(earliest))
        #expect(vm.latestEntryMonth == startOfMonth(latest))
    }

    @Test func navigateMonthClampsAtEarliestBound() {
        let earliest = monthsAgo(2)
        let task = makeTask(timeEntries: [entry(start: earliest, end: earliest.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        vm.navigateMonth(by: -1)
        vm.navigateMonth(by: -1)
        vm.navigateMonth(by: -1)
        #expect(vm.displayMonth == startOfMonth(earliest))
        #expect(vm.canNavigateBackward == false)
    }

    @Test func navigateMonthClampsAtLatestBound() {
        let now = Date()
        let task = makeTask(timeEntries: [entry(start: now, end: now.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        vm.navigateMonth(by: 1)
        vm.navigateMonth(by: 1)
        #expect(vm.displayMonth == startOfMonth(now))
        #expect(vm.canNavigateForward == false)
    }

    @Test func setDisplayMonthClampsOutOfRangeRequest() {
        let earliest = monthsAgo(2)
        let latest = monthsAgo(0)
        let task = makeTask(timeEntries: [
            entry(start: earliest, end: earliest.addingTimeInterval(3600)),
            entry(start: latest, end: latest.addingTimeInterval(3600)),
        ])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        vm.setDisplayMonth(year: 1990, month: 1)
        #expect(vm.displayMonth == startOfMonth(earliest))
    }

    // MARK: - Aggregation

    @Test func hoursForDayReflectsAggregatedTotalsAcrossAllTasks() {
        let now = Date()
        let day = calendar.startOfDay(for: now)
        let taskA = makeTask(timeEntries: [entry(start: day, end: day.addingTimeInterval(3600))])
        let taskB = makeTask(timeEntries: [entry(start: day.addingTimeInterval(7200), end: day.addingTimeInterval(9000))])
        let (vm, _, _) = makeVM(tasks: [taskA, taskB])
        vm.onAppear()
        #expect(vm.hoursForDay(day) == 3600 + 1800)
    }

    @Test func hoursForDayIsZeroWhenNoEntriesThatDay() {
        let now = Date()
        let task = makeTask(timeEntries: [entry(start: now, end: now.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        let unrelatedDay = calendar.date(byAdding: .day, value: -10, to: calendar.startOfDay(for: now))!
        #expect(vm.hoursForDay(unrelatedDay) == 0)
    }

    // MARK: - Month total

    @Test func monthTotalSumsAllDaysInDisplayedMonth() {
        let now = Date()
        let day = calendar.startOfDay(for: now)
        let otherDay = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        let taskA = makeTask(timeEntries: [entry(start: day, end: day.addingTimeInterval(3600))])
        let taskB = makeTask(timeEntries: [entry(start: otherDay, end: otherDay.addingTimeInterval(1800))])
        let (vm, _, _) = makeVM(tasks: [taskA, taskB])
        vm.onAppear()
        let expected: TimeInterval = 3600 + 1800
        #expect(vm.monthTotal == expected)
    }

    @Test func monthTotalIsZeroForMonthWithNoEntries() {
        let (vm, _, _) = makeVM()
        vm.onAppear()
        #expect(vm.monthTotal == 0)
    }

    // MARK: - Today button

    @Test func isCurrentMonthAvailableTrueWhenCurrentMonthHasEntries() {
        let now = Date()
        let task = makeTask(timeEntries: [entry(start: now, end: now.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        #expect(vm.isCurrentMonthAvailable == true)
    }

    @Test func isCurrentMonthAvailableFalseWhenCurrentMonthHasNoEntries() {
        let pastDate = monthsAgo(3)
        let task = makeTask(timeEntries: [entry(start: pastDate, end: pastDate.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [task])
        vm.onAppear()
        #expect(vm.isCurrentMonthAvailable == false)
    }

    @Test func jumpToTodayNavigatesToCurrentMonth() {
        let now = Date()
        let pastDate = monthsAgo(3, from: now)
        let taskA = makeTask(timeEntries: [entry(start: pastDate, end: pastDate.addingTimeInterval(3600))])
        let taskB = makeTask(timeEntries: [entry(start: now, end: now.addingTimeInterval(3600))])
        let (vm, _, _) = makeVM(tasks: [taskA, taskB])
        vm.onAppear()
        vm.navigateMonth(by: -1)
        #expect(vm.displayMonth != startOfMonth(now))
        vm.jumpToToday()
        #expect(vm.displayMonth == startOfMonth(now))
    }
}
