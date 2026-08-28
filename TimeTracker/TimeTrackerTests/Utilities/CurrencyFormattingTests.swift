import Testing
import Foundation
@testable import TimeTracker

struct CurrencyFormattingTests {

    // MARK: - Amounts

    @Test func amountIsPrefixedWithTheSymbol() {
        #expect(CurrencyFormatting.amount(10, symbol: "$").hasPrefix("$"))
        #expect(CurrencyFormatting.amount(10, symbol: "€").hasPrefix("€"))
        #expect(CurrencyFormatting.amount(10, symbol: "zł").hasPrefix("zł"))
    }

    @Test func amountAlwaysShowsTwoFractionDigits() {
        // The decimal separator itself is locale-dependent, so count the trailing digits.
        let formatted = CurrencyFormatting.amount(10, symbol: "$")
        #expect(formatted.suffix(2) == "00")
        #expect(CurrencyFormatting.amount(10.5, symbol: "$").suffix(2) == "50")
        #expect(CurrencyFormatting.amount(10.567, symbol: "$").suffix(2) == "57")
    }

    @Test func amountGroupsThousandsWithCommas() {
        #expect(CurrencyFormatting.amount(1225.50, symbol: "$").contains("1,225"))
        #expect(CurrencyFormatting.amount(1_000_000, symbol: "$").contains("1,000,000"))
    }

    @Test func amountHandlesZeroAndNegatives() {
        #expect(CurrencyFormatting.amount(0, symbol: "$").hasPrefix("$"))
        #expect(CurrencyFormatting.amount(-42, symbol: "$").contains("42"))
    }

    // MARK: - Rates

    @Test func wholeRateOmitsFractionDigits() {
        #expect(CurrencyFormatting.rate(50, symbol: "$") == "$50/h")
        #expect(CurrencyFormatting.rate(0, symbol: "$") == "$0/h")
    }

    @Test func fractionalRateShowsTwoDigits() {
        #expect(CurrencyFormatting.rate(62.5, symbol: "$") == "$62.50/h")
    }

    @Test func largeRateAlwaysShowsTwoDigits() {
        #expect(CurrencyFormatting.rate(10000, symbol: "$") == "$10000.00/h")
    }

    @Test func rateUsesTheGivenSymbol() {
        #expect(CurrencyFormatting.rate(50, symbol: "€") == "€50/h")
    }
}
