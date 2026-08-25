import SwiftUI

struct HeatmapView: View {
    @State var viewModel: HeatmapViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if viewModel.hasAnyEntries {
                content
            } else {
                emptyState
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear { viewModel.onAppear() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            monthYearPickers

            HStack {
                (Text("Total this month: ") + Text(viewModel.monthTotal.formattedHoursMinutes).bold())
                    .font(.title3)
                    .foregroundStyle(.primary)

                Spacer()

                colorLegend
            }

            CalendarHeatmapView(
                displayMonth: viewModel.displayMonth,
                hoursForDay: { viewModel.hoursForDay($0) },
                onMonthChange: { viewModel.navigateMonth(by: $0) },
                colorStrategy: AllTasksHeatmapColorStrategy(targetHours: viewModel.targetDailyHours),
                selectedDate: viewModel.selectedDate,
                onSelectDay: { viewModel.selectDay($0) },
                showsTimeLabel: true,
                canGoBackward: viewModel.canNavigateBackward,
                canGoForward: viewModel.canNavigateForward,
                selectionOverridesTodayHighlight: true
            )

            if let selectedDate = viewModel.selectedDate {
                trackedTasksSection(for: selectedDate)
            }

            Spacer()
        }
        .padding()
    }

    private func trackedTasksSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracked tasks")
                .font(.headline)

            if viewModel.selectedDayTaskRows.isEmpty {
                Text("No time tracked on \(formattedDate(date)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.selectedDayTaskRows) { row in
                            trackedTaskRow(row)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func trackedTaskRow(_ row: SelectedDayTaskRow) -> some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(row.tags.prefix(3)) { tag in
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 30, alignment: .leading)

            Text(row.title)
                .lineLimit(1)

            Spacer()

            Text(row.duration.formattedHoursMinutes)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private var monthYearPickers: some View {
        HStack(spacing: 12) {
            Picker("Month", selection: monthBinding) {
                ForEach(viewModel.availableMonthsForDisplayedYear, id: \.self) { month in
                    Text(monthName(month)).tag(month)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            Picker("Year", selection: yearBinding) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 120)

            Button("Today") {
                viewModel.jumpToToday()
            }
            .disabled(!viewModel.isCurrentMonthAvailable)
        }
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.month, from: viewModel.displayMonth) },
            set: { newMonth in
                let year = Calendar.current.component(.year, from: viewModel.displayMonth)
                viewModel.setDisplayMonth(year: year, month: newMonth)
            }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.year, from: viewModel.displayMonth) },
            set: { newYear in
                let month = Calendar.current.component(.month, from: viewModel.displayMonth)
                viewModel.setDisplayMonth(year: newYear, month: month)
            }
        )
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }

    private var colorLegend: some View {
        let strategy = AllTasksHeatmapColorStrategy(targetHours: viewModel.targetDailyHours)
        return HStack(spacing: 4) {
            Text("0h")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(Array(strategy.legendColors(colorScheme: colorScheme).enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 14, height: 14)
            }
            Text("\(Int(viewModel.targetDailyHours / 3600))h+")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No time tracked yet")
                .font(.headline)
            Text("Track some time to see your heatmap here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
