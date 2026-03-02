import Testing
import Foundation
import UserNotifications
@testable import TimeTracker

@MainActor
struct TrackingReminderServiceTests {

    private func makeService(
        reminderEnabled: Bool = true,
        days: [Int] = [2, 3, 4, 5, 6],
        timeSeconds: TimeInterval = 9 * 3600
    ) -> (DefaultTrackingReminderService, MockUserPreferencesService, MockTimerService) {
        let prefs = MockUserPreferencesService()
        prefs.stubbedTrackingReminderEnabled = reminderEnabled
        prefs.stubbedTrackingReminderDays = days
        prefs.stubbedTrackingReminderTime = timeSeconds
        let timer = MockTimerService()
        let service = DefaultTrackingReminderService(
            userPreferences: prefs,
            timerService: timer
        )
        return (service, prefs, timer)
    }

    @Test func rescheduleDoesNothingWhenDisabled() {
        let (service, prefs, _) = makeService(reminderEnabled: false)
        service.rescheduleNotifications()
        #expect(prefs.stubbedTrackingReminderEnabled == false)
    }

    @Test func cancelAllNotificationsDoesNotCrash() {
        let (service, _, _) = makeService()
        service.cancelAllNotifications()
    }

    @Test func rescheduleNotificationsDoesNotCrash() {
        let (service, _, _) = makeService(reminderEnabled: true, days: [2, 6])
        service.rescheduleNotifications()
    }

    @Test func rescheduleWithEmptyDaysDoesNotCrash() {
        let (service, _, _) = makeService(reminderEnabled: true, days: [])
        service.rescheduleNotifications()
    }
}
