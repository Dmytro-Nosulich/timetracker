import SwiftUI

struct CalendarHeatmapView: View {
    let displayMonth: Date
    @Binding var selectedDate: Date
    let hoursForDay: (Date) -> TimeInterval
    let onMonthChange: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    onMonthChange(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

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
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            hours: hoursForDay(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isInDisplayMonth: calendar.isDate(date, equalTo: displayMonth, toGranularity: .month),
                            colorScheme: colorScheme
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
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
    let action: () -> Void

    private var heatColor: Color {
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

    var body: some View {
        Button(action: action) {
            VStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption)
                    .foregroundStyle(isInDisplayMonth ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(heatColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
