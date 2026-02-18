import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case allTime = "All Time"
    case customRange = "Custom Range"

    var id: String { rawValue }

    func dateRange(calendar: Calendar = .current, now: Date = Date()) -> (start: Date, end: Date) {
        switch self {
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
            let endOfSunday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday)!
            return (monday, endOfSunday)

        case .lastWeek:
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = (weekday + 5) % 7
            let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
            let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday)!
            let endOfSunday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastSunday)!
            return (lastMonday, endOfSunday)

        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let firstDay = calendar.date(from: components)!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)!
            let lastDay = calendar.date(byAdding: .second, value: -1, to: nextMonth)!
            return (firstDay, lastDay)

        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let firstDayThisMonth = calendar.date(from: components)!
            let firstDayLastMonth = calendar.date(byAdding: .month, value: -1, to: firstDayThisMonth)!
            let lastDayLastMonth = calendar.date(byAdding: .second, value: -1, to: firstDayThisMonth)!
            return (firstDayLastMonth, lastDayLastMonth)

        case .thisYear:
            var startComponents = calendar.dateComponents([.year], from: now)
            startComponents.month = 1
            startComponents.day = 1
            let firstDay = calendar.date(from: startComponents)!
            var endComponents = startComponents
            endComponents.year = (endComponents.year ?? 0) + 1
            let nextYear = calendar.date(from: endComponents)!
            let lastDay = calendar.date(byAdding: .second, value: -1, to: nextYear)!
            return (firstDay, lastDay)

        case .allTime:
            let distantPast = Date.distantPast
            let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return (distantPast, endOfToday)

        case .customRange:
            let components = calendar.dateComponents([.year, .month], from: now)
            let firstDay = calendar.date(from: components)!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)!
            let lastDay = calendar.date(byAdding: .second, value: -1, to: nextMonth)!
            return (firstDay, lastDay)
        }
    }

    func defaultFilename(startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()

        switch self {
        case .thisMonth, .lastMonth:
            formatter.dateFormat = "MMMM yyyy"
            return "Time Report - \(formatter.string(from: startDate))"
        case .thisWeek, .lastWeek:
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: startDate)
            formatter.dateFormat = "MMM d yyyy"
            let end = formatter.string(from: endDate)
            return "Time Report - \(start) - \(end)"
        case .thisYear:
            formatter.dateFormat = "yyyy"
            return "Time Report - \(formatter.string(from: startDate))"
        case .allTime:
            return "Time Report - All Time"
        case .customRange:
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: startDate)
            formatter.dateFormat = "MMM d yyyy"
            let end = formatter.string(from: endDate)
            return "Time Report - \(start) - \(end)"
        }
    }
}
