import Foundation

/// `@unchecked Sendable` because the only stored property is a `UserDefaults`, which is
/// documented thread-safe — every accessor below is a plain read or write through it.
final class UserDefaultsUserPreferencesService: UserPreferencesService, @unchecked Sendable {
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
    private let taskReminderEnabledKey = "taskReminderEnabled"
    private let taskReminderDurationKey = "taskReminderDuration"
    private let taskReminderModeKey = "taskReminderMode"
    private let targetDailyHoursKey = "targetDailyHours"
    private let mcpServerEnabledKey = "mcpServerEnabled"
    private let mcpServerPortKey = "mcpServerPort"

    static let defaultIdleTimeoutMinutes = 10
    static let defaultSubtractIdleTimeFromTrackedTime = false
    static let defaultTrackingReminderTimeSeconds: TimeInterval = 9 * 3600 // 09:00
    static let defaultTrackingReminderDays = [2, 3, 4, 5, 6] // Mon-Fri (Calendar weekday)
    static let defaultTargetDailyHoursSeconds: TimeInterval = 8 * 3600
    /// On by default so the server keeps auto-starting for anyone who was using it before
    /// the setting existed, and so an unattended skill works without visiting Settings.
    static let defaultMCPServerEnabled = true

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

    var taskReminderEnabled: Bool {
        guard userDefaults.object(forKey: taskReminderEnabledKey) != nil else {
            return false
        }
        return userDefaults.bool(forKey: taskReminderEnabledKey)
    }

    func setTaskReminderEnabled(_ value: Bool) {
        userDefaults.set(value, forKey: taskReminderEnabledKey)
    }

    var taskReminderDuration: TimeInterval {
        guard userDefaults.object(forKey: taskReminderDurationKey) != nil else {
            return 3600
        }
        return userDefaults.double(forKey: taskReminderDurationKey)
    }

    func setTaskReminderDuration(_ value: TimeInterval) {
        userDefaults.set(value, forKey: taskReminderDurationKey)
    }

    var taskReminderMode: TaskReminderMode {
        guard let raw = userDefaults.string(forKey: taskReminderModeKey),
              let mode = TaskReminderMode(rawValue: raw) else {
            return .currentSession
        }
        return mode
    }

    func setTaskReminderMode(_ value: TaskReminderMode) {
        userDefaults.set(value.rawValue, forKey: taskReminderModeKey)
    }

    var targetDailyHours: TimeInterval {
        guard userDefaults.object(forKey: targetDailyHoursKey) != nil else {
            return Self.defaultTargetDailyHoursSeconds
        }
        return userDefaults.double(forKey: targetDailyHoursKey)
    }

    func setTargetDailyHours(_ value: TimeInterval) {
        userDefaults.set(value, forKey: targetDailyHoursKey)
    }

    var mcpServerEnabled: Bool {
        guard userDefaults.object(forKey: mcpServerEnabledKey) != nil else {
            return Self.defaultMCPServerEnabled
        }
        return userDefaults.bool(forKey: mcpServerEnabledKey)
    }

    func setMCPServerEnabled(_ value: Bool) {
        userDefaults.set(value, forKey: mcpServerEnabledKey)
    }

    /// Range-guarded on read: a stored value the server could never bind (0, a privileged
    /// port, something out of range) falls back to the default rather than leaving the
    /// server permanently unable to start.
    var mcpServerPort: Int {
        guard let stored = userDefaults.object(forKey: mcpServerPortKey) as? Int,
              MCPServerConfiguration.validPortRange.contains(stored) else {
            return MCPServerConfiguration.defaultPort
        }
        return stored
    }

    func setMCPServerPort(_ value: Int) {
        userDefaults.set(value, forKey: mcpServerPortKey)
    }
}
