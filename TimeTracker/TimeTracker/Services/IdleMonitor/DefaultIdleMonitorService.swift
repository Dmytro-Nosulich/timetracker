import AppKit
import CoreGraphics
import Foundation
import UserNotifications

@Observable
@MainActor
final class DefaultIdleMonitorService: IdleMonitorService {
    private let timerService: TimerService
    private let userPreferences: UserPreferencesService
    private let localStorage: LocalStorageService

    private var pollTimer: Timer?
    private static let pollInterval: TimeInterval = 30
    private static let userReturnIdleThreshold: TimeInterval = 30
    private var showedWelcomeBackForCurrentPause = false

    init(timerService: TimerService, userPreferences: UserPreferencesService, localStorage: LocalStorageService) {
        self.timerService = timerService
        self.userPreferences = userPreferences
        self.localStorage = localStorage
    }

    func start() {
        requestNotificationAuthorizationIfNeeded()
        startPollTimer()
        observeSleepWake()
    }

    // MARK: - Poll Timer

    private func startPollTimer() {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        pollTimer?.tolerance = 5
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        let idleSeconds = currentIdleTime()
        let state = timerService.state

        switch state {
        case .running:
            let thresholdSeconds = TimeInterval(userPreferences.idleTimeoutMinutes * 60)
            if idleSeconds >= thresholdSeconds {
                timerService.pauseDueToInactivity(idleDuration: idleSeconds)
                sendPausedNotification()
            }
        case .pausedByInactivity:
            if idleSeconds < Self.userReturnIdleThreshold, !showedWelcomeBackForCurrentPause {
                showedWelcomeBackForCurrentPause = true
                showWelcomeBackDialog()
            }
        case .idle, .pausedByUser:
            showedWelcomeBackForCurrentPause = false
            break
        }
    }

    private func currentIdleTime() -> TimeInterval {
		CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }

    // MARK: - Sleep / Wake

    private func observeSleepWake() {
        let workspace = NSWorkspace.shared
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWillSleep()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDidWake()
            }
        }
    }

    private func handleWillSleep() {
        guard timerService.state == .running else { return }
        let idleSeconds = currentIdleTime()
        timerService.pauseDueToInactivity(idleDuration: idleSeconds)
        sendPausedNotification()
    }

    private func handleDidWake() {
        guard timerService.state == .pausedByInactivity else { return }
        if !showedWelcomeBackForCurrentPause {
            showedWelcomeBackForCurrentPause = true
            showWelcomeBackDialog()
        }
    }

    // MARK: - Welcome Back Dialog

    private func showWelcomeBackDialog() {
        let taskName: String
        if let taskId = timerService.currentTaskId, let task = localStorage.fetchTask(id: taskId) {
            taskName = task.title
        } else {
            taskName = NSLocalizedString("Unknown task", comment: "Fallback when task not found")
        }

        let minutesAgo: Int
        if let pauseDate = timerService.inactivityPauseDate {
            minutesAgo = max(1, Int(Date().timeIntervalSince(pauseDate) / 60))
        } else {
            minutesAgo = 1
        }

        let message = String(
            format: NSLocalizedString(
                "Your timer was paused %d minutes ago due to inactivity.\n\nTask: %@",
                comment: "Welcome back dialog message"
            ),
            minutesAgo,
            taskName
        )

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Welcome back!", comment: "Welcome back dialog title")
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Resume Timer", comment: "Welcome back dialog button"))
        alert.addButton(withTitle: NSLocalizedString("Keep Paused", comment: "Welcome back dialog button"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            timerService.resumeTimer()
        } else {
            timerService.setPausedByUser()
        }
    }

    // MARK: - Notifications

    private func requestNotificationAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendPausedNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Time Tracker", comment: "Notification title")
        content.body = NSLocalizedString("Timer paused — no activity detected", comment: "Idle pause notification")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
