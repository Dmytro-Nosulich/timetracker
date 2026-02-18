import Foundation

final class UserDefaultsUserPreferencesService: UserPreferencesService {
    private let userDefaults: UserDefaults
    private let currencySymbolKey = "currencySymbol"
    private let idleTimeoutMinutesKey = "idleTimeoutMinutes"
    private let subtractIdleTimeFromTrackedTimeKey = "subtractIdleTimeFromTrackedTime"

    static let defaultIdleTimeoutMinutes = 10
    static let defaultSubtractIdleTimeFromTrackedTime = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currencySymbol: String {
        userDefaults.string(forKey: currencySymbolKey) ?? "$"
    }

    func setCurrencySymbol(_ value: String) {
        userDefaults.set(value, forKey: currencySymbolKey)
    }

    var idleTimeoutMinutes: Int {
        let stored = userDefaults.object(forKey: idleTimeoutMinutesKey) as? Int
        return stored ?? Self.defaultIdleTimeoutMinutes
    }

    func setIdleTimeoutMinutes(_ value: Int) {
        userDefaults.set(value, forKey: idleTimeoutMinutesKey)
    }

    var subtractIdleTimeFromTrackedTime: Bool {
        guard userDefaults.object(forKey: subtractIdleTimeFromTrackedTimeKey) != nil else {
            return Self.defaultSubtractIdleTimeFromTrackedTime
        }
        return userDefaults.bool(forKey: subtractIdleTimeFromTrackedTimeKey)
    }

    func setSubtractIdleTimeFromTrackedTime(_ value: Bool) {
        userDefaults.set(value, forKey: subtractIdleTimeFromTrackedTimeKey)
    }
}
