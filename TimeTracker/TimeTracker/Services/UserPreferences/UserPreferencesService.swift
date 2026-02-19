import Foundation

protocol UserPreferencesService {
    var currencySymbol: String { get }
    func setCurrencySymbol(_ value: String)

    var currencyCode: String { get }
    func setCurrencyCode(_ value: String)

    var idleTimeoutMinutes: Int { get }
    func setIdleTimeoutMinutes(_ value: Int)

    var subtractIdleTimeFromTrackedTime: Bool { get }
    func setSubtractIdleTimeFromTrackedTime(_ value: Bool)

    var businessName: String { get }
    func setBusinessName(_ value: String)

    var defaultHourlyRate: Double? { get }
    func setDefaultHourlyRate(_ value: Double?)

    var timeRounding: String { get }
    func setTimeRounding(_ value: String)

    var trackingReminderEnabled: Bool { get }
    func setTrackingReminderEnabled(_ value: Bool)

    var trackingReminderTime: TimeInterval { get }
    func setTrackingReminderTime(_ value: TimeInterval)

    var trackingReminderDays: [Int] { get }
    func setTrackingReminderDays(_ value: [Int])
}
