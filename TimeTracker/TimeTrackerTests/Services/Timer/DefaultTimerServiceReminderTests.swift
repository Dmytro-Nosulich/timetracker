import Testing
import Foundation
import UserNotifications
@testable import TimeTracker

@MainActor
struct DefaultTimerServiceReminderTests {

    private func makeTask(id: UUID = UUID(), title: String = "Test Task", totalTrackedTime: TimeInterval = 0) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: "",
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: [],
            totalTrackedTime: totalTrackedTime,
            trackedTimeToday: 0
        )
    }

    /// Puts the service into .running with sessionElapsed == elapsedSeconds
    /// by stubbing an open entry that started `elapsedSeconds` ago.
    private func startRunning(
        service: DefaultTimerService,
        storage: MockLocalStorageService,
        dp: MockDateProvider,
        taskId: UUID,
        elapsedSeconds: TimeInterval
    ) {
        let startDate = dp.currentDate.addingTimeInterval(-elapsedSeconds)
        storage.stubbedOpenTimeEntry = (
            entry: TimeEntryItem(id: UUID(), startDate: startDate, endDate: nil, isManual: false, note: nil),
            taskId: taskId
        )
        service.recoverFromCrashIfNeeded()
    }

    private func makeService(
        prefs: MockUserPreferencesService = MockUserPreferencesService(),
        storage: MockLocalStorageService = MockLocalStorageService(),
        dp: MockDateProvider = MockDateProvider(),
        onNotification: @escaping (UNNotificationRequest) -> Void = { _ in }
    ) -> (service: DefaultTimerService, storage: MockLocalStorageService, prefs: MockUserPreferencesService, dp: MockDateProvider) {
        let service = DefaultTimerService(
            localStorage: storage,
            dateProvider: dp,
            userPreferences: prefs,
            notificationScheduler: onNotification
        )
        return (service, storage, prefs, dp)
    }

    // MARK: - currentSession mode

    @Test func reminderFiresWhenCurrentSessionReachesThreshold() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationFired = true
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 3600)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == true)
    }

    @Test func reminderDoesNotFireWhenDisabled() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = false
        prefs.stubbedTaskReminderDuration = 60
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationFired = true
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 120)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == false)
    }

    @Test func reminderDoesNotFireWhenBelowThreshold() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationFired = true
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 1800)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == false)
    }

    @Test func reminderFiresOnlyOncePerSessionContext() {
        var notificationCount = 0
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationCount += 1
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 3600)

        service.checkAndFireTaskReminderIfNeeded()
        service.checkAndFireTaskReminderIfNeeded()
        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationCount == 1)
    }

    @Test func reminderResetsAfterTaskSwitch() {
        var notificationCount = 0
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        // Use today mode so threshold check uses the stubbed storage value,
        // avoiding the need to manipulate sessionElapsed across sessions
        prefs.stubbedTaskReminderMode = .today

        let storage = MockLocalStorageService()
        storage.stubbedTrackedTimeTodayForTask = 3600  // at threshold

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, _, _, _) = makeService(prefs: prefs, storage: storage, dp: dp) { _ in
            notificationCount += 1
        }

        // First task session crosses threshold
        let task1 = makeTask(id: UUID())
        service.startTimer(for: task1)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 1)

        // Switch to new task — resets the flag
        let task2 = makeTask(id: UUID())
        service.startTimer(for: task2)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 2)
    }

    @Test func reminderResetsAfterPauseAndResume() {
        var notificationCount = 0
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationCount += 1
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 3600)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 1)

        service.pauseTimer()

        // Resume: creates a new session, flag resets
        service.resumeTimer()

        // Advance time past threshold again for the new session
        dp.currentDate = dp.currentDate.addingTimeInterval(3600)
        storage.stubbedOpenTimeEntry = nil
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 3600)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 2)
    }

    @Test func reminderResetsWhenDurationChanges() {
        var notificationCount = 0
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .currentSession

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, storage, _, _) = makeService(prefs: prefs, dp: dp) { _ in
            notificationCount += 1
        }

        let taskId = UUID()
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 3600)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 1)

        // Increase duration — flag resets, and now elapsed (3600) < new threshold (7200)
        prefs.stubbedTaskReminderDuration = 7200
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 1) // did not fire again (3600 < 7200)

        // Advance session elapsed past new threshold
        service.saveAndStop()
        dp.currentDate = dp.currentDate.addingTimeInterval(3600)
        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 7200)
        service.checkAndFireTaskReminderIfNeeded()
        #expect(notificationCount == 2)
    }

    // MARK: - today mode

    @Test func reminderUsesTodayStorageForTodayMode() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .today

        let taskId = UUID()
        let storage = MockLocalStorageService()
        storage.stubbedTrackedTimeTodayForTask = 3600

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, _, _, _) = makeService(prefs: prefs, storage: storage, dp: dp) { _ in
            notificationFired = true
        }

        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 0)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == true)
        #expect(storage.trackedTimeTodayForTaskCallCount >= 1)
    }

    @Test func reminderDoesNotFireWhenTodayBelowThreshold() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .today

        let taskId = UUID()
        let storage = MockLocalStorageService()
        storage.stubbedTrackedTimeTodayForTask = 1800  // only 30 min

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, _, _, _) = makeService(prefs: prefs, storage: storage, dp: dp) { _ in
            notificationFired = true
        }

        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 0)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == false)
    }

    // MARK: - allTime mode

    @Test func reminderUsesTotalTrackedTimeForAllTimeMode() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 3600
        prefs.stubbedTaskReminderMode = .allTime

        let taskId = UUID()
        let task = makeTask(id: taskId, totalTrackedTime: 3600)
        let storage = MockLocalStorageService()
        storage.stubbedFetchedTask = task

        let dp = MockDateProvider()
        dp.currentDate = Date()
        let (service, _, _, _) = makeService(prefs: prefs, storage: storage, dp: dp) { _ in
            notificationFired = true
        }

        startRunning(service: service, storage: storage, dp: dp, taskId: taskId, elapsedSeconds: 0)

        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == true)
        #expect(storage.fetchTaskCallCount >= 1)
    }

    @Test func reminderDoesNotFireWhenTimerIsNotRunning() {
        var notificationFired = false
        let prefs = MockUserPreferencesService()
        prefs.stubbedTaskReminderEnabled = true
        prefs.stubbedTaskReminderDuration = 0
        prefs.stubbedTaskReminderMode = .currentSession

        let (service, _, _, _) = makeService(prefs: prefs) { _ in
            notificationFired = true
        }

        // State is .idle — never started timer
        service.checkAndFireTaskReminderIfNeeded()

        #expect(notificationFired == false)
    }
}
