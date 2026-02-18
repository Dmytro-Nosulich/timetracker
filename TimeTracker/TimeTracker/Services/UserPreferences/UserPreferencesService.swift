import Foundation

protocol UserPreferencesService {
    var currencySymbol: String { get }
    func setCurrencySymbol(_ value: String)

    var idleTimeoutMinutes: Int { get }
    func setIdleTimeoutMinutes(_ value: Int)

    var subtractIdleTimeFromTrackedTime: Bool { get }
    func setSubtractIdleTimeFromTrackedTime(_ value: Bool)
}
