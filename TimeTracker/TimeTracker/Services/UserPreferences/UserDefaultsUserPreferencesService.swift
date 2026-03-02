import Foundation

final class UserDefaultsUserPreferencesService: UserPreferencesService {
    private let userDefaults: UserDefaults
    private let currencySymbolKey = "currencySymbol"
    private let currencyCodeKey = "currencyCode"
    private let idleTimeoutMinutesKey = "idleTimeoutMinutes"
    private let subtractIdleTimeFromTrackedTimeKey = "subtractIdleTimeFromTrackedTime"
    private let businessNameKey = "businessName"
    private let defaultHourlyRateKey = "defaultHourlyRate"
    private let timeRoundingKey = "timeRounding"
    private let trackingReminderEnabledKey = "trackingReminderEnabled"
    private let trackingReminderTimeKey = "trackingReminderTime"
    private let trackingReminderDaysKey = "trackingReminderDays"

    static let defaultIdleTimeoutMinutes = 10
    static let defaultSubtractIdleTimeFromTrackedTime = false
    static let defaultTrackingReminderTimeSeconds: TimeInterval = 9 * 3600 // 09:00
    static let defaultTrackingReminderDays = [2, 3, 4, 5, 6] // Mon-Fri (Calendar weekday)

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currencySymbol: String {
        userDefaults.string(forKey: currencySymbolKey) ?? "$"
    }

    func setCurrencySymbol(_ value: String) {
        userDefaults.set(value, forKey: currencySymbolKey)
    }

    var currencyCode: String {
        userDefaults.string(forKey: currencyCodeKey) ?? "USD"
    }

    func setCurrencyCode(_ value: String) {
        userDefaults.set(value, forKey: currencyCodeKey)
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

    var trackingReminderEnabled: Bool {
        guard userDefaults.object(forKey: trackingReminderEnabledKey) != nil else {
            return false
        }
        return userDefaults.bool(forKey: trackingReminderEnabledKey)
    }

    func setTrackingReminderEnabled(_ value: Bool) {
        userDefaults.set(value, forKey: trackingReminderEnabledKey)
    }

    var trackingReminderTime: TimeInterval {
        guard userDefaults.object(forKey: trackingReminderTimeKey) != nil else {
            return Self.defaultTrackingReminderTimeSeconds
        }
        return userDefaults.double(forKey: trackingReminderTimeKey)
    }

    func setTrackingReminderTime(_ value: TimeInterval) {
        userDefaults.set(value, forKey: trackingReminderTimeKey)
    }

    var trackingReminderDays: [Int] {
        guard let data = userDefaults.data(forKey: trackingReminderDaysKey),
              let days = try? JSONDecoder().decode([Int].self, from: data) else {
            return Self.defaultTrackingReminderDays
        }
        return days
    }

    func setTrackingReminderDays(_ value: [Int]) {
        if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: trackingReminderDaysKey)
        }
    }
}
