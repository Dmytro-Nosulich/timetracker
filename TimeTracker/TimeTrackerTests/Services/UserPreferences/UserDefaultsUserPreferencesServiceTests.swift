import Testing
import Foundation
@testable import TimeTracker

struct UserDefaultsUserPreferencesServiceTests {

    private func makeService() -> (UserDefaultsUserPreferencesService, UserDefaults) {
        let suiteName = "test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let service = UserDefaultsUserPreferencesService(userDefaults: userDefaults)
        return (service, userDefaults)
    }

    @Test func currencySymbolDefaultsToDollar() {
        let (service, _) = makeService()
        #expect(service.currencySymbol == "$")
    }

    @Test func setCurrencySymbolPersistsValue() {
        let (service, _) = makeService()
        service.setCurrencySymbol("€")
        #expect(service.currencySymbol == "€")
    }

    @Test func setCurrencySymbolOverwritesPrevious() {
        let (service, _) = makeService()
        service.setCurrencySymbol("£")
        service.setCurrencySymbol("¥")
        #expect(service.currencySymbol == "¥")
    }

    @Test func currencySymbolReturnsEmptyWhenKeyExistsButValueEmpty() {
        let (service, userDefaults) = makeService()
        userDefaults.set("", forKey: "currencySymbol")
        #expect(service.currencySymbol == "")
    }

    @Test func setAndGetRoundtrip() {
        let (service, _) = makeService()
        service.setCurrencySymbol("CHF")
        #expect(service.currencySymbol == "CHF")
    }

    @Test func eachTestUsesIsolatedUserDefaults() {
        let (service1, _) = makeService()
        let (service2, _) = makeService()

        service1.setCurrencySymbol("€")
        #expect(service1.currencySymbol == "€")
        #expect(service2.currencySymbol == "$")
    }

    // MARK: - Idle timeout

    @Test func idleTimeoutMinutesDefaultsToTen() {
        let (service, _) = makeService()
        #expect(service.idleTimeoutMinutes == 10)
    }

    @Test func setIdleTimeoutMinutesPersistsValue() {
        let (service, _) = makeService()
        service.setIdleTimeoutMinutes(5)
        #expect(service.idleTimeoutMinutes == 5)
    }

    @Test func setIdleTimeoutMinutesOverwritesPrevious() {
        let (service, _) = makeService()
        service.setIdleTimeoutMinutes(15)
        service.setIdleTimeoutMinutes(1)
        #expect(service.idleTimeoutMinutes == 1)
    }

    // MARK: - Subtract idle time

    @Test func subtractIdleTimeFromTrackedTimeDefaultsToFalse() {
        let (service, _) = makeService()
        #expect(service.subtractIdleTimeFromTrackedTime == false)
    }

    @Test func setSubtractIdleTimeFromTrackedTimePersistsValue() {
        let (service, _) = makeService()
        service.setSubtractIdleTimeFromTrackedTime(true)
        #expect(service.subtractIdleTimeFromTrackedTime == true)
    }

    @Test func subtractIdleTimeRoundtrip() {
        let (service, _) = makeService()
        service.setSubtractIdleTimeFromTrackedTime(true)
        #expect(service.subtractIdleTimeFromTrackedTime == true)
        service.setSubtractIdleTimeFromTrackedTime(false)
        #expect(service.subtractIdleTimeFromTrackedTime == false)
    }

    // MARK: - Business name

    @Test func businessNameDefaultsToEmpty() {
        let (service, _) = makeService()
        #expect(service.businessName == "")
    }

    @Test func setBusinessNamePersistsValue() {
        let (service, _) = makeService()
        service.setBusinessName("Acme Corp")
        #expect(service.businessName == "Acme Corp")
    }

    @Test func setBusinessNameOverwritesPrevious() {
        let (service, _) = makeService()
        service.setBusinessName("First")
        service.setBusinessName("Second")
        #expect(service.businessName == "Second")
    }

    // MARK: - Default hourly rate

    @Test func defaultHourlyRateDefaultsToNil() {
        let (service, _) = makeService()
        #expect(service.defaultHourlyRate == nil)
    }

    @Test func setDefaultHourlyRatePersistsValue() {
        let (service, _) = makeService()
        service.setDefaultHourlyRate(50.0)
        #expect(service.defaultHourlyRate == 50.0)
    }

    @Test func setDefaultHourlyRateToNilRemovesValue() {
        let (service, _) = makeService()
        service.setDefaultHourlyRate(75.0)
        #expect(service.defaultHourlyRate == 75.0)
        service.setDefaultHourlyRate(nil)
        #expect(service.defaultHourlyRate == nil)
    }

    @Test func setDefaultHourlyRateOverwritesPrevious() {
        let (service, _) = makeService()
        service.setDefaultHourlyRate(50.0)
        service.setDefaultHourlyRate(100.0)
        #expect(service.defaultHourlyRate == 100.0)
    }

    // MARK: - Time rounding

    @Test func timeRoundingDefaultsToNone() {
        let (service, _) = makeService()
        #expect(service.timeRounding == "none")
    }

    @Test func setTimeRoundingPersistsValue() {
        let (service, _) = makeService()
        service.setTimeRounding("15")
        #expect(service.timeRounding == "15")
    }

    @Test func setTimeRoundingOverwritesPrevious() {
        let (service, _) = makeService()
        service.setTimeRounding("5")
        service.setTimeRounding("30")
        #expect(service.timeRounding == "30")
    }

    @Test func timeRoundingRoundtrip() {
        let (service, _) = makeService()
        for value in ["none", "5", "15", "30"] {
            service.setTimeRounding(value)
            #expect(service.timeRounding == value)
        }
    }
}
