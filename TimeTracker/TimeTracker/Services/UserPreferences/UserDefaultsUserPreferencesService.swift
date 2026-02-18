import Foundation

final class UserDefaultsUserPreferencesService: UserPreferencesService {
    private let userDefaults: UserDefaults
    private let currencySymbolKey = "currencySymbol"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currencySymbol: String {
        userDefaults.string(forKey: currencySymbolKey) ?? "$"
    }

    func setCurrencySymbol(_ value: String) {
        userDefaults.set(value, forKey: currencySymbolKey)
    }
}
