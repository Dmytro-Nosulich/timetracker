import Foundation
@testable import TimeTracker

final class MockUserPreferencesService: UserPreferencesService {
    var stubbedCurrencySymbol: String = "$"
    var setCurrencySymbolCallCount = 0
    var setCurrencySymbolLastValue: String?

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
    }

    var idleTimeoutMinutes: Int {
        stubbedIdleTimeoutMinutes
    }

    func setIdleTimeoutMinutes(_ value: Int) {
        setIdleTimeoutMinutesCallCount += 1
        setIdleTimeoutMinutesLastValue = value
    }

    var subtractIdleTimeFromTrackedTime: Bool {
        stubbedSubtractIdleTimeFromTrackedTime
    }

    func setSubtractIdleTimeFromTrackedTime(_ value: Bool) {
        setSubtractIdleTimeFromTrackedTimeCallCount += 1
        setSubtractIdleTimeFromTrackedTimeLastValue = value
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
    }
}
