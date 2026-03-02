import SwiftUI

struct ReportView: View {
    @State var viewModel: ReportViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                businessNameSection
                periodSection
                zeroTimeToggle
            }
            .padding()

            Divider()

            selectAllHeader

            Divider()

            taskTable

            Divider()

            totalsBar

            Divider()

            exportButton
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Business Name

    private var businessNameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Report Name / Business")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Business name", text: $viewModel.businessName)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Period Picker

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)

            HStack(spacing: 12) {
                DatePicker(
                    "From",
                    selection: $viewModel.startDate,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.startDate) {
                    viewModel.onStartDateChanged()
                }

                DatePicker(
                    "To",
                    selection: $viewModel.endDate,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.endDate) {
                    viewModel.onEndDateChanged()
                }
            }
        }
    }

    // MARK: - Zero Time Toggle

    private var zeroTimeToggle: some View {
        Toggle("Include tasks with zero time", isOn: $viewModel.includeZeroTime)
    }

    // MARK: - Select All

    private var selectAllHeader: some View {
        HStack {
            Toggle(isOn: $viewModel.allSelected) {
                Text("Select All")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Task Table

    private var taskTable: some View {
        List {
            ForEach(viewModel.taskRows) { row in
                taskRowView(row)
            }
        }
        .listStyle(.plain)
    }

    private func taskRowView(_ row: ReportTaskRowItem) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { row.isSelected },
                set: { _ in viewModel.toggleTask(row.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(row.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.roundedTime.formattedHoursMinutes)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            if viewModel.showAmountColumn {
                Text(viewModel.formattedAmount(for: row) ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(row.amount != nil ? .primary : .secondary)
                    .frame(width: 100, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Totals

    private var totalsBar: some View {
        HStack {
            Text("Total selected: \(viewModel.totalSelectedTime.formattedHoursMinutes)")
                .fontWeight(.medium)

            Spacer()

            if viewModel.showAmountColumn, let totalAmount = viewModel.totalSelectedAmount {
                Text("Total: \(viewModel.formatCurrency(totalAmount))")
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Export

    private var exportButton: some View {
        HStack {
            Spacer()
            Button("Export PDF") {
                viewModel.exportPDF()
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}
