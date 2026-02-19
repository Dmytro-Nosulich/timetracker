import Foundation
@testable import TimeTracker

@MainActor
final class MockTrackingReminderService: TrackingReminderService {
    var rescheduleNotificationsCallCount = 0
    var cancelAllNotificationsCallCount = 0

    func rescheduleNotifications() {
        rescheduleNotificationsCallCount += 1
    }

    func cancelAllNotifications() {
        cancelAllNotificationsCallCount += 1
    }
}
