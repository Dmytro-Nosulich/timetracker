import SwiftUI

struct CalendarHeatmapView: View {
    let displayMonth: Date
    let hoursForDay: (Date) -> TimeInterval
    let onMonthChange: (Int) -> Void
    let colorStrategy: HeatmapColorStrategy
    var selectedDate: Date? = nil
    var onSelectDay: ((Date) -> Void)? = nil
    var showsTimeLabel: Bool = false
    var timeLabelFormatter: (TimeInterval) -> String = { $0.formattedCompactHours }
    var canGoBackward: Bool = true
    var canGoForward: Bool = true
    var selectionOverridesTodayHighlight: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var cellHeight: CGFloat { showsTimeLabel ? 44 : 32 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    onMonthChange(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!canGoBackward)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Spacer()

                Text(monthYearString)
                    .font(.headline)

                Spacer()

                Button {
                    onMonthChange(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!canGoForward)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        let hours = hoursForDay(date)
                        DayCell(
                            date: date,
                            hours: hours,
                            isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                            isInDisplayMonth: calendar.isDate(date, equalTo: displayMonth, toGranularity: .month),
                            colorScheme: colorScheme,
                            colorStrategy: colorStrategy,
                            label: showsTimeLabel ? timeLabelFormatter(hours) : nil,
                            cellHeight: cellHeight,
                            selectionOverridesTodayHighlight: selectionOverridesTodayHighlight,
                            action: onSelectDay.map { onSelectDay in { onSelectDay(date) } }
                        )
                    } else {
                        Color.clear
                            .frame(height: cellHeight)
                    }
                }
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) else {
            return []
        }

        var startWeekday = calendar.component(.weekday, from: firstDay)
        if startWeekday == 1 { startWeekday = 8 }
        let leadingBlanks = startWeekday - 2

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}

private struct DayCell: View {
    let date: Date
    let hours: TimeInterval
    let isSelected: Bool
    let isInDisplayMonth: Bool
    let colorScheme: ColorScheme
    let colorStrategy: HeatmapColorStrategy
    let label: String?
    let cellHeight: CGFloat
    let selectionOverridesTodayHighlight: Bool
    let action: (() -> Void)?

    var body: some View {
        if let action, !isFuture {
            Button(action: action) { cellContent }
                .buttonStyle(.plain)
        } else {
            cellContent
        }
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    private var showsTodayRing: Bool {
        !(isSelected && selectionOverridesTodayHighlight)
    }

    private var cellContent: some View {
        VStack(spacing: 1) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .foregroundStyle((isInDisplayMonth && !isFuture) ? .primary : .secondary)
            if let label, !isFuture {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(isInDisplayMonth ? .primary : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight)
        .contentShape(Rectangle())
        .background(colorStrategy.color(forHours: hours, colorScheme: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .inset(by: (isSelected && showsTodayRing) ? 3 : 0)
                .stroke((isToday && showsTodayRing) ? Color.red : Color.clear, lineWidth: 1.5)
        )
    }
}
