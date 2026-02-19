import Foundation
@testable import TimeTracker

final class MockUserPreferencesService: UserPreferencesService {
    var stubbedCurrencySymbol: String = "$"
    var setCurrencySymbolCallCount = 0
    var setCurrencySymbolLastValue: String?

    var stubbedCurrencyCode: String = "USD"
    var setCurrencyCodeCallCount = 0
    var setCurrencyCodeLastValue: String?

    var stubbedIdleTimeoutMinutes: Int = 10
    var setIdleTimeoutMinutesCallCount = 0
    var setIdleTimeoutMinutesLastValue: Int?

    var stubbedSubtractIdleTimeFromTrackedTime: Bool = false
    var setSubtractIdleTimeFromTrackedTimeCallCount = 0
    var setSubtractIdleTimeFromTrackedTimeLastValue: Bool?

    var currencySymbol: String {
        stubbedCurrencySymbol
    }

    func setCurrencySymbol(_ value: String) {
        setCurrencySymbolCallCount += 1
        setCurrencySymbolLastValue = value
        stubbedCurrencySymbol = value
    }

    var currencyCode: String {
        stubbedCurrencyCode
    }

    func setCurrencyCode(_ value: String) {
        setCurrencyCodeCallCount += 1
        setCurrencyCodeLastValue = value
        stubbedCurrencyCode = value
    }

    var idleTimeoutMinutes: Int {
        stubbedIdleTimeoutMinutes
    }

    func setIdleTimeoutMinutes(_ value: Int) {
        setIdleTimeoutMinutesCallCount += 1
        setIdleTimeoutMinutesLastValue = value
        stubbedIdleTimeoutMinutes = value
    }

    var subtractIdleTimeFromTrackedTime: Bool {
        stubbedSubtractIdleTimeFromTrackedTime
    }

    func setSubtractIdleTimeFromTrackedTime(_ value: Bool) {
        setSubtractIdleTimeFromTrackedTimeCallCount += 1
        setSubtractIdleTimeFromTrackedTimeLastValue = value
        stubbedSubtractIdleTimeFromTrackedTime = value
    }

    var stubbedBusinessName: String = ""
    var setBusinessNameCallCount = 0
    var setBusinessNameLastValue: String?

    var businessName: String {
        stubbedBusinessName
    }

    func setBusinessName(_ value: String) {
        setBusinessNameCallCount += 1
        setBusinessNameLastValue = value
        stubbedBusinessName = value
    }

    var stubbedDefaultHourlyRate: Double?
    var setDefaultHourlyRateCallCount = 0
    var setDefaultHourlyRateLastValue: Double??

    var defaultHourlyRate: Double? {
        stubbedDefaultHourlyRate
    }

    func setDefaultHourlyRate(_ value: Double?) {
        setDefaultHourlyRateCallCount += 1
        setDefaultHourlyRateLastValue = value
        stubbedDefaultHourlyRate = value
    }

    var stubbedTimeRounding: String = "none"
    var setTimeRoundingCallCount = 0
    var setTimeRoundingLastValue: String?

    var timeRounding: String {
        stubbedTimeRounding
    }

    func setTimeRounding(_ value: String) {
        setTimeRoundingCallCount += 1
        setTimeRoundingLastValue = value
        stubbedTimeRounding = value
    }

    var stubbedTrackingReminderEnabled: Bool = false
    var setTrackingReminderEnabledCallCount = 0
    var setTrackingReminderEnabledLastValue: Bool?

    var trackingReminderEnabled: Bool {
        stubbedTrackingReminderEnabled
    }

    func setTrackingReminderEnabled(_ value: Bool) {
        setTrackingReminderEnabledCallCount += 1
        setTrackingReminderEnabledLastValue = value
        stubbedTrackingReminderEnabled = value
    }

    var stubbedTrackingReminderTime: TimeInterval = 9 * 3600
    var setTrackingReminderTimeCallCount = 0
    var setTrackingReminderTimeLastValue: TimeInterval?

    var trackingReminderTime: TimeInterval {
        stubbedTrackingReminderTime
    }

    func setTrackingReminderTime(_ value: TimeInterval) {
        setTrackingReminderTimeCallCount += 1
        setTrackingReminderTimeLastValue = value
        stubbedTrackingReminderTime = value
    }

    var stubbedTrackingReminderDays: [Int] = [2, 3, 4, 5, 6]
    var setTrackingReminderDaysCallCount = 0
    var setTrackingReminderDaysLastValue: [Int]?

    var trackingReminderDays: [Int] {
        stubbedTrackingReminderDays
    }

    func setTrackingReminderDays(_ value: [Int]) {
        setTrackingReminderDaysCallCount += 1
        setTrackingReminderDaysLastValue = value
        stubbedTrackingReminderDays = value
    }
}
