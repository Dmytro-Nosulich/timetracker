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
}
