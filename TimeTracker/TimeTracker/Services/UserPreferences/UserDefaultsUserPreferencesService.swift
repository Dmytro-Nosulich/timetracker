import Foundation

final class UserDefaultsUserPreferencesService: UserPreferencesService {
    private let userDefaults: UserDefaults
    private let currencySymbolKey = "currencySymbol"
    private let idleTimeoutMinutesKey = "idleTimeoutMinutes"
    private let subtractIdleTimeFromTrackedTimeKey = "subtractIdleTimeFromTrackedTime"
    private let businessNameKey = "businessName"
    private let defaultHourlyRateKey = "defaultHourlyRate"
    private let timeRoundingKey = "timeRounding"

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

    var businessName: String {
        userDefaults.string(forKey: businessNameKey) ?? ""
    }

    func setBusinessName(_ value: String) {
        userDefaults.set(value, forKey: businessNameKey)
    }

    var defaultHourlyRate: Double? {
        userDefaults.object(forKey: defaultHourlyRateKey) as? Double
    }

    func setDefaultHourlyRate(_ value: Double?) {
        if let value {
            userDefaults.set(value, forKey: defaultHourlyRateKey)
        } else {
            userDefaults.removeObject(forKey: defaultHourlyRateKey)
        }
    }

    var timeRounding: String {
        userDefaults.string(forKey: timeRoundingKey) ?? "none"
    }

    func setTimeRounding(_ value: String) {
        userDefaults.set(value, forKey: timeRoundingKey)
    }
}
