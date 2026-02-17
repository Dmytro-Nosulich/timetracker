import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TimeFormattingTests {

    @Test func zeroSeconds() {
        let interval: TimeInterval = 0
        #expect(interval.formattedHoursMinutes == "0h 00m")
    }

    @Test func lessThanOneMinute() {
        let interval: TimeInterval = 59
        #expect(interval.formattedHoursMinutes == "0h 00m")
    }

    @Test func exactlyOneMinute() {
        let interval: TimeInterval = 60
        #expect(interval.formattedHoursMinutes == "0h 01m")
    }

    @Test func exactlyOneHour() {
        let interval: TimeInterval = 3600
        #expect(interval.formattedHoursMinutes == "1h 00m")
    }

    @Test func oneHourThirtyMinutes() {
        let interval: TimeInterval = 5400
        #expect(interval.formattedHoursMinutes == "1h 30m")
    }

    @Test func twelveHoursThirtyMinutes() {
        let interval: TimeInterval = 45000
        #expect(interval.formattedHoursMinutes == "12h 30m")
    }

    @Test func largeValue() {
        let interval: TimeInterval = 523800
        #expect(interval.formattedHoursMinutes == "145h 30m")
    }
}
