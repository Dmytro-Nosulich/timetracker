import Testing
import Foundation
@testable import TimeTracker

struct TimeRoundingTests {

    // MARK: - TimeRoundingInterval init

    @Test func initFromValidRawString() {
        #expect(TimeRoundingInterval(rawString: "none") == .none)
        #expect(TimeRoundingInterval(rawString: "5") == .fiveMinutes)
        #expect(TimeRoundingInterval(rawString: "15") == .fifteenMinutes)
        #expect(TimeRoundingInterval(rawString: "30") == .thirtyMinutes)
    }

    @Test func initFromInvalidRawStringDefaultsToNone() {
        #expect(TimeRoundingInterval(rawString: "invalid") == .none)
        #expect(TimeRoundingInterval(rawString: "") == .none)
        #expect(TimeRoundingInterval(rawString: "10") == .none)
    }

    @Test func secondsValues() {
        #expect(TimeRoundingInterval.none.seconds == 0)
        #expect(TimeRoundingInterval.fiveMinutes.seconds == 300)
        #expect(TimeRoundingInterval.fifteenMinutes.seconds == 900)
        #expect(TimeRoundingInterval.thirtyMinutes.seconds == 1800)
    }

    // MARK: - Rounding with .none

    @Test func roundingNoneReturnsOriginal() {
        let interval: TimeInterval = 123.456
        #expect(interval.rounded(to: .none) == 123.456)
    }

    @Test func roundingNonePreservesZero() {
        let interval: TimeInterval = 0
        #expect(interval.rounded(to: .none) == 0)
    }

    // MARK: - Rounding with 5 minutes

    @Test func fiveMinuteRoundingExactBoundary() {
        let fiveMinutes: TimeInterval = 300
        #expect(fiveMinutes.rounded(to: .fiveMinutes) == 300)
    }

    @Test func fiveMinuteRoundingRoundsDown() {
        // 2 minutes = 120s -> rounds down to 0
        let twoMinutes: TimeInterval = 120
        #expect(twoMinutes.rounded(to: .fiveMinutes) == 0)
    }

    @Test func fiveMinuteRoundingRoundsUp() {
        // 3 minutes = 180s -> rounds up to 5 min (300s)
        let threeMinutes: TimeInterval = 180
        #expect(threeMinutes.rounded(to: .fiveMinutes) == 300)
    }

    @Test func fiveMinuteRoundingMidpoint() {
        // 2.5 minutes = 150s -> rounds to nearest (5 min = 300s)
        let twoAndHalf: TimeInterval = 150
        #expect(twoAndHalf.rounded(to: .fiveMinutes) == 300)
    }

    @Test func fiveMinuteRoundingSevenMinutes() {
        // 7 min = 420s -> rounds down to 5 min (300s)
        let sevenMin: TimeInterval = 420
        #expect(sevenMin.rounded(to: .fiveMinutes) == 300)
    }

    @Test func fiveMinuteRoundingEightMinutes() {
        // 8 min = 480s -> rounds up to 10 min (600s)
        let eightMin: TimeInterval = 480
        #expect(eightMin.rounded(to: .fiveMinutes) == 600)
    }

    // MARK: - Rounding with 15 minutes

    @Test func fifteenMinuteRoundingExactBoundary() {
        let fifteenMinutes: TimeInterval = 900
        #expect(fifteenMinutes.rounded(to: .fifteenMinutes) == 900)
    }

    @Test func fifteenMinuteRoundingSevenMinutes() {
        // 7 min = 420s -> rounds down to 0
        let sevenMin: TimeInterval = 420
        #expect(sevenMin.rounded(to: .fifteenMinutes) == 0)
    }

    @Test func fifteenMinuteRoundingEightMinutes() {
        // 8 min = 480s -> rounds up to 15 min (900s)
        let eightMin: TimeInterval = 480
        #expect(eightMin.rounded(to: .fifteenMinutes) == 900)
    }

    @Test func fifteenMinuteRoundingTwentyMinutes() {
        // 20 min = 1200s -> rounds down to 15 min (900s)
        let twentyMin: TimeInterval = 1200
        #expect(twentyMin.rounded(to: .fifteenMinutes) == 900)
    }

    @Test func fifteenMinuteRoundingTwentyThreeMinutes() {
        // 23 min = 1380s -> rounds up to 30 min (1800s)
        let twentyThreeMin: TimeInterval = 1380
        #expect(twentyThreeMin.rounded(to: .fifteenMinutes) == 1800)
    }

    // MARK: - Rounding with 30 minutes

    @Test func thirtyMinuteRoundingExactBoundary() {
        let thirtyMinutes: TimeInterval = 1800
        #expect(thirtyMinutes.rounded(to: .thirtyMinutes) == 1800)
    }

    @Test func thirtyMinuteRoundingFourteenMinutes() {
        // 14 min = 840s -> rounds down to 0
        let fourteenMin: TimeInterval = 840
        #expect(fourteenMin.rounded(to: .thirtyMinutes) == 0)
    }

    @Test func thirtyMinuteRoundingFifteenMinutes() {
        // 15 min = 900s -> rounds to 30 min (1800s)
        let fifteenMin: TimeInterval = 900
        #expect(fifteenMin.rounded(to: .thirtyMinutes) == 1800)
    }

    @Test func thirtyMinuteRoundingFortyFiveMinutes() {
        // 45 min = 2700s -> rounds to 60 min (3600s)
        let fortyFiveMin: TimeInterval = 2700
        #expect(fortyFiveMin.rounded(to: .thirtyMinutes) == 3600)
    }

    // MARK: - Zero time

    @Test func roundingZeroAlwaysReturnsZero() {
        let zero: TimeInterval = 0
        #expect(zero.rounded(to: .none) == 0)
        #expect(zero.rounded(to: .fiveMinutes) == 0)
        #expect(zero.rounded(to: .fifteenMinutes) == 0)
        #expect(zero.rounded(to: .thirtyMinutes) == 0)
    }

    // MARK: - Large values

    @Test func roundingLargeValue() {
        // 2h 37m = 9420s -> with 15 min rounding: 9420/900 = 10.467 -> rounds to 10 * 900 = 9000s = 2h 30m
        let twoHoursThirtySeven: TimeInterval = 9420
        #expect(twoHoursThirtySeven.rounded(to: .fifteenMinutes) == 9000)
    }
}
