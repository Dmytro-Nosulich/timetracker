import SwiftUI

/// 8 discrete opacity tiers, spanning a configurable daily-hours target, capped
/// at the darkest tier once the target is reached — so hitting exactly the target
/// and exceeding it by any amount render identically, with no separate "overtime" color.
struct AllTasksHeatmapColorStrategy: HeatmapColorStrategy {
    private let targetSeconds: TimeInterval
    private let tierCount = 8

    private let lightOpacities: [Double] = [0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.86, 1.0]
    private let darkOpacities: [Double] = [0.16, 0.28, 0.40, 0.52, 0.64, 0.76, 0.88, 1.0]

    init(targetHours: TimeInterval) {
        self.targetSeconds = max(targetHours, 1)
    }

    func color(forHours hours: TimeInterval, colorScheme: ColorScheme) -> Color {
        guard hours > 0 else { return Color.clear }
        let bucketSize = targetSeconds / Double(tierCount)
        let bucket = Int(ceil(hours / bucketSize))
        let tierIndex = min(max(bucket, 1), tierCount) - 1
        let opacities = colorScheme == .dark ? darkOpacities : lightOpacities
        return Color.green.opacity(opacities[tierIndex])
    }

    /// One representative color per tier, for a legend — built on `color(forHours:)`
    /// directly so it can never drift out of sync with actual cell colors.
    func legendColors(colorScheme: ColorScheme) -> [Color] {
        let bucketSize = targetSeconds / Double(tierCount)
        return (1...tierCount).map { tier in
            color(forHours: bucketSize * Double(tier), colorScheme: colorScheme)
        }
    }
}
