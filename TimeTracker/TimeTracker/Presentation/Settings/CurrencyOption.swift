import Foundation

enum CurrencyOption: String, CaseIterable, Identifiable {
    case usd
    case eur
    case gbp
    case cad
    case aud
    case jpy
    case chf
    case custom

    var id: String { rawValue }

    var code: String {
        switch self {
        case .usd: return "USD"
        case .eur: return "EUR"
        case .gbp: return "GBP"
        case .cad: return "CAD"
        case .aud: return "AUD"
        case .jpy: return "JPY"
        case .chf: return "CHF"
        case .custom: return "CUSTOM"
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "C$"
        case .aud: return "A$"
        case .jpy: return "¥"
        case .chf: return "CHF"
        case .custom: return ""
        }
    }

    var displayName: String {
        switch self {
        case .usd: return "USD ($)"
        case .eur: return "EUR (€)"
        case .gbp: return "GBP (£)"
        case .cad: return "CAD (C$)"
        case .aud: return "AUD (A$)"
        case .jpy: return "JPY (¥)"
        case .chf: return "CHF (CHF)"
        case .custom: return "Custom"
        }
    }

    static func from(code: String) -> CurrencyOption {
        CurrencyOption.allCases.first { $0.code == code } ?? .custom
    }
}
