import Testing
import SwiftUI
@testable import TimeTracker

struct AllTasksHeatmapColorStrategyTests {

    @Test func zeroHoursIsClear() {
        let strategy = AllTasksHeatmapColorStrategy(targetHours: 8 * 3600)
        #expect(strategy.color(forHours: 0, colorScheme: .light) == Color.clear)
    }

    @Test func targetAndBeyondRenderIdentically() {
        let strategy = AllTasksHeatmapColorStrategy(targetHours: 8 * 3600)
        let atTarget = strategy.color(forHours: 8 * 3600, colorScheme: .light)
        let wellOver = strategy.color(forHours: 14 * 3600, colorScheme: .light)
        let barelyOver = strategy.color(forHours: 8 * 3600 + 60, colorScheme: .light)
        #expect(atTarget == wellOver)
        #expect(atTarget == barelyOver)
    }

    @Test func sameAbsoluteHoursProduceDifferentTiersForDifferentTargets() {
        let lowTarget = AllTasksHeatmapColorStrategy(targetHours: 4 * 3600)
        let highTarget = AllTasksHeatmapColorStrategy(targetHours: 12 * 3600)
        let hours: TimeInterval = 4 * 3600
        let lowTargetColor = lowTarget.color(forHours: hours, colorScheme: .light)
        let highTargetColor = highTarget.color(forHours: hours, colorScheme: .light)
        // 4h against a 4h target is the capped/darkest tier; 4h against a 12h target is a lighter mid-tier.
        #expect(lowTargetColor != highTargetColor)
    }

    @Test func legendColorsHasOneEntryPerTierAndMatchesRealCellColors() {
        let strategy = AllTasksHeatmapColorStrategy(targetHours: 8 * 3600)
        let legend = strategy.legendColors(colorScheme: .light)
        #expect(legend.count == 8)
        let bucketSize: TimeInterval = 8 * 3600 / 8
        for (index, expectedColor) in legend.enumerated() {
            let hours = bucketSize * TimeInterval(index + 1)
            #expect(strategy.color(forHours: hours, colorScheme: .light) == expectedColor)
        }
    }
}
