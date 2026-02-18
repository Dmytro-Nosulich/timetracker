import Foundation
@testable import TimeTracker

final class MockUserPreferencesService: UserPreferencesService {
    var stubbedCurrencySymbol: String = "$"
    var setCurrencySymbolCallCount = 0
    var setCurrencySymbolLastValue: String?

    var currencySymbol: String {
        stubbedCurrencySymbol
    }

    func setCurrencySymbol(_ value: String) {
        setCurrencySymbolCallCount += 1
        setCurrencySymbolLastValue = value
    }
}
