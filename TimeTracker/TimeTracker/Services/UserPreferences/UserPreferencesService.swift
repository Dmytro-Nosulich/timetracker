import Foundation

protocol UserPreferencesService {
    var currencySymbol: String { get }
    func setCurrencySymbol(_ value: String)
}
