import SwiftUI

protocol HeatmapColorStrategy {
    func color(forHours hours: TimeInterval, colorScheme: ColorScheme) -> Color
}

/// Reproduces the original single-task heatmap coloring: four tiers based on
/// absolute hour thresholds, tuned for a single task's daily hours.
struct TaskHeatmapColorStrategy: HeatmapColorStrategy {
    func color(forHours hours: TimeInterval, colorScheme: ColorScheme) -> Color {
        switch hours {
        case 0:
            return Color.clear
        case ..<7200:
            return colorScheme == .dark ? Color.green.opacity(0.3) : Color.green.opacity(0.25)
        case ..<18000:
            return colorScheme == .dark ? Color.green.opacity(0.55) : Color.green.opacity(0.5)
        default:
            return colorScheme == .dark ? Color.green.opacity(0.8) : Color.green.opacity(0.75)
        }
    }
}
