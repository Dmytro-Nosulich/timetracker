import Foundation

protocol UserPreferencesService {
    var currencySymbol: String { get }
    func setCurrencySymbol(_ value: String)

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
}
