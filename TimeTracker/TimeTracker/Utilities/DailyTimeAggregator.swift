import Foundation

/// Aggregates tracked time per calendar day across a set of time entries, clipping
/// each entry to every individual day it spans — so an entry crossing midnight is
/// split proportionally across both days rather than double-counted or attributed
/// entirely to its start day.
enum DailyTimeAggregator {
    static func dailyTotals(
        for entries: [TimeEntryItem],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for entry in entries {
            let entryEnd = entry.endDate ?? now
            guard entry.startDate < rangeEnd, entryEnd > rangeStart else { continue }
            let clippedStart = max(entry.startDate, rangeStart)
            let clippedEnd = min(entryEnd, rangeEnd)
            guard clippedEnd > clippedStart else { continue }

            var cursor = calendar.startOfDay(for: clippedStart)
            while cursor < clippedEnd {
                guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                let segmentStart = max(cursor, clippedStart)
                let segmentEnd = min(nextDayStart, clippedEnd)
                if segmentEnd > segmentStart {
                    totals[cursor, default: 0] += segmentEnd.timeIntervalSince(segmentStart)
                }
                cursor = nextDayStart
            }
        }
        return totals
    }

    /// Total tracked time across a range, with every entry clipped to it. Defined in terms
    /// of `dailyTotals` so a range total and its per-day breakdown can never disagree.
    static func total(
        for entries: [TimeEntryItem],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> TimeInterval {
        dailyTotals(
            for: entries,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            calendar: calendar,
            now: now
        ).values.reduce(0, +)
    }
}
