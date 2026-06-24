import Foundation
import UserNotifications

@MainActor
final class DefaultTrackingReminderService: NSObject, TrackingReminderService {
    private let userPreferences: UserPreferencesService
    private let timerService: TimerService
    private let notificationCenter: UNUserNotificationCenter

	nonisolated
    private static let notificationCategoryId = "trackingReminder"
    private static let notificationIdPrefix = "tracking-reminder-day-"

    init(
        userPreferences: UserPreferencesService,
        timerService: TimerService,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.userPreferences = userPreferences
        self.timerService = timerService
        self.notificationCenter = notificationCenter
        super.init()
        notificationCenter.delegate = self
    }

    func rescheduleNotifications() {
        cancelAllNotifications()

        guard userPreferences.trackingReminderEnabled else { return }

        let days = userPreferences.trackingReminderDays
        let timeSeconds = userPreferences.trackingReminderTime
        let hour = Int(timeSeconds) / 3600
        let minute = (Int(timeSeconds) % 3600) / 60

        for weekday in days {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = "Time Tracker"
            content.body = "Don't forget to start tracking your time!"
            content.sound = .default
            content.categoryIdentifier = Self.notificationCategoryId

            let requestId = "\(Self.notificationIdPrefix)\(weekday)"
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }

    func cancelAllNotifications() {
        let ids = (1...7).map { "\(Self.notificationIdPrefix)\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func requestPermissionIfNeeded() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

extension DefaultTrackingReminderService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.content.categoryIdentifier == Self.notificationCategoryId else {
            completionHandler([.banner, .sound])
            return
        }

        let options: UNNotificationPresentationOptions = MainActor.assumeIsolated {
            timerService.state == .running ? [] : [.banner, .sound]
        }
        completionHandler(options)
    }
}
