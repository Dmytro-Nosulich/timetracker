import Foundation

@MainActor
protocol TrackingReminderService {
    func rescheduleNotifications()
    func cancelAllNotifications()
}
