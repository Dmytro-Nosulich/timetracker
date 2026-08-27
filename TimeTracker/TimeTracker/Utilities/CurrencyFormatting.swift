import Foundation

/// Formats monetary values for the Report screen and the exported PDF. Both must
/// produce identical strings, so the formatting lives here rather than on either one.
enum CurrencyFormatting {
    /// A currency amount with two fraction digits, e.g. "$1,225.50".
    static func amount(_ value: Double, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(symbol)\(formatted)"
    }

    /// An hourly rate, e.g. "$50/h" or "$62.50/h".
    static func rate(_ value: Double, symbol: String) -> String {
        "\(symbol)\(number(value))/h"
    }

    private static func number(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
