import Foundation
import UserNotifications

@Observable
@MainActor
final class DefaultTimerService: TimerService {
    private let localStorage: LocalStorageService
    private let dateProvider: DateProvider
    private let userPreferences: UserPreferencesService
    let notificationScheduler: (UNNotificationRequest) -> Void

    // MARK: - Observable State

    private(set) var currentTaskId: UUID?
    private(set) var sessionStartDate: Date?
    private(set) var sessionElapsed: TimeInterval = 0
    private(set) var state: TimerState = .idle
    private(set) var inactivityPauseDate: Date?

    // MARK: - Internal Tracking

    private var currentEntryId: UUID?
    private var tickTimer: Timer?
    private var lastTickDate: Date?
    private var lastEmittedMinute: Int = -1

    // MARK: - Task Reminder State

    private var reminderAlreadyFired = false
    private var lastKnownReminderDuration: TimeInterval = 0
    private var lastKnownReminderMode: TaskReminderMode = .currentSession

    // MARK: - Init

    init(
        localStorage: LocalStorageService,
        dateProvider: DateProvider = SystemDateProvider(),
        userPreferences: UserPreferencesService,
        notificationScheduler: @escaping (UNNotificationRequest) -> Void = { UNUserNotificationCenter.current().add($0) }
    ) {
        self.localStorage = localStorage
        self.dateProvider = dateProvider
        self.userPreferences = userPreferences
        self.notificationScheduler = notificationScheduler
    }

    // MARK: - Public Methods

    func startTimer(for task: TaskItem) {
        let now = dateProvider.now()

        switch state {
        case .running:
            guard currentTaskId != task.id else { return }
            // Switch task: close current entry, keep session running
            closeCurrentEntry(endDate: now)

        case .pausedByUser, .pausedByInactivity:
            // Resume from pause: reset session
            inactivityPauseDate = nil

        case .idle:
            // Start fresh
			break
        }

		let offset = task.totalTrackedTime.truncatingRemainder(dividingBy: 60)
		createNewEntry(for: task.id, startDate: now)
		currentTaskId = task.id
		sessionStartDate = now - offset
		sessionElapsed = offset
		lastEmittedMinute = -1
        reminderAlreadyFired = false

        state = .running
        lastTickDate = now
        startInternalTimer()
    }

    func pauseTimer() {
        guard state == .running else { return }

        let now = dateProvider.now()
        closeCurrentEntry(endDate: now)
        sessionElapsed = 0
        lastEmittedMinute = -1
        inactivityPauseDate = nil
        state = .pausedByUser
        stopInternalTimer()
    }

    func resumeTimer() {
        guard let taskId = currentTaskId,
              state == .pausedByUser || state == .pausedByInactivity else { return }

        let now = dateProvider.now()
        let offset = localStorage.fetchTask(id: taskId)?.totalTrackedTime.truncatingRemainder(dividingBy: 60) ?? 0
        inactivityPauseDate = nil
        createNewEntry(for: taskId, startDate: now)
        sessionStartDate = now - offset
        sessionElapsed = offset
        lastEmittedMinute = -1
        reminderAlreadyFired = false
        state = .running
        lastTickDate = now
        startInternalTimer()
    }

    func pauseDueToInactivity(idleDuration: TimeInterval) {
        guard state == .running else { return }

        let now = dateProvider.now()
        let endDate: Date
        if userPreferences.subtractIdleTimeFromTrackedTime {
            endDate = now.addingTimeInterval(-idleDuration)
        } else {
            endDate = now
        }
        closeCurrentEntry(endDate: endDate)
        inactivityPauseDate = now
        state = .pausedByInactivity
        stopInternalTimer()
    }

    func setPausedByUser() {
        guard state == .pausedByInactivity else { return }
        inactivityPauseDate = nil
        state = .pausedByUser
    }

    @discardableResult
    func recoverFromCrashIfNeeded() -> CrashRecoveryResult {
        guard let openEntry = localStorage.fetchOpenTimeEntry() else {
            return .noOpenEntry
        }

        let now = dateProvider.now()
        let calendar = Calendar.current
        let isFromPreviousDay = !calendar.isDate(openEntry.entry.startDate, inSameDayAs: now)
        let hoursElapsed = now.timeIntervalSince(openEntry.entry.startDate) / 3600

        if isFromPreviousDay || hoursElapsed > 12 {
            return .staleEntry(
                entryId: openEntry.entry.id,
                taskId: openEntry.taskId,
                startDate: openEntry.entry.startDate
            )
        }

        // Recent entry — auto-resume
        currentTaskId = openEntry.taskId
        currentEntryId = openEntry.entry.id
        sessionStartDate = openEntry.entry.startDate
        sessionElapsed = now.timeIntervalSince(openEntry.entry.startDate)
        state = .running
        lastTickDate = now
        startInternalTimer()

        return .resumedRecent(taskId: openEntry.taskId)
    }

    func saveAndStop() {
        guard state == .running || state == .pausedByUser || state == .pausedByInactivity else { return }

        if state == .running {
            let now = dateProvider.now()
            closeCurrentEntry(endDate: now)
        }
        stopInternalTimer()
        inactivityPauseDate = nil
        state = .idle
        currentTaskId = nil
        sessionStartDate = nil
        sessionElapsed = 0
        lastEmittedMinute = -1
    }

    // MARK: - Internal Timer

    private func startInternalTimer() {
        stopInternalTimer()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopInternalTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard state == .running, let start = sessionStartDate else { return }

        let now = dateProvider.now()
        sessionElapsed = now.timeIntervalSince(start)

        let currentMinute = Int(sessionElapsed) / 60
        if currentMinute != lastEmittedMinute {
            lastEmittedMinute = currentMinute
            NotificationCenter.default.post(name: .timerDisplayDidUpdate, object: nil)
        }

        checkAndFireTaskReminderIfNeeded()
        handleMidnightRollover(now: now)
        lastTickDate = now
    }

    // MARK: - Task Reminder

    func checkAndFireTaskReminderIfNeeded() {
        let currentDuration = userPreferences.taskReminderDuration
        let currentMode = userPreferences.taskReminderMode

        if currentDuration != lastKnownReminderDuration || currentMode != lastKnownReminderMode {
            reminderAlreadyFired = false
            lastKnownReminderDuration = currentDuration
            lastKnownReminderMode = currentMode
        }

        guard userPreferences.taskReminderEnabled,
              !reminderAlreadyFired,
              let taskId = currentTaskId else { return }

        let elapsed: TimeInterval
        switch currentMode {
        case .currentSession:
            elapsed = sessionElapsed
        case .today:
            elapsed = localStorage.trackedTimeToday(for: taskId)
        case .allTime:
            elapsed = localStorage.fetchTask(id: taskId)?.totalTrackedTime ?? 0
        }

        guard elapsed >= currentDuration else { return }

        reminderAlreadyFired = true

        let taskTitle = localStorage.fetchTask(id: taskId)?.title ?? "your task"
        sendTaskReminderNotification(taskTitle: taskTitle, elapsed: elapsed)
    }

    private func sendTaskReminderNotification(taskTitle: String, elapsed: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "You've spent \(elapsed.formattedHoursMinutes) on \"\(taskTitle)\""
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "task-reminder-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        notificationScheduler(request)
    }

    // MARK: - Midnight Rollover

    private func handleMidnightRollover(now: Date) {
        guard let lastTick = lastTickDate else { return }

        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: lastTick)
        let currentDay = calendar.startOfDay(for: now)

        guard lastDay != currentDay, let taskId = currentTaskId else { return }

        // Close entry at end of previous day (23:59:59)
        let endOfPreviousDay = currentDay.addingTimeInterval(-1)
        closeCurrentEntry(endDate: endOfPreviousDay)

        // Create new entry at start of new day (00:00:00)
        createNewEntry(for: taskId, startDate: currentDay)
    }

    // MARK: - Entry Management

    private func closeCurrentEntry(endDate: Date) {
        guard let entryId = currentEntryId else { return }
        localStorage.closeTimeEntry(id: entryId, endDate: endDate)
        currentEntryId = nil
    }

    private func createNewEntry(for taskId: UUID, startDate: Date) {
        if let entry = localStorage.createTimeEntry(startDate: startDate, for: taskId) {
            currentEntryId = entry.id
        }
    }
}
