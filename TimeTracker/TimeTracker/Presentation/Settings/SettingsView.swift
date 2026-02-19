import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel

    var body: some View {
        Form {
            generalSection
            idleDetectionSection
            notificationsSection
            tagsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 500)
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            TextField("Business Name", text: $viewModel.businessName)

            TextField("Default Hourly Rate", text: $viewModel.defaultHourlyRateText)
                .textFieldStyle(.roundedBorder)

            Picker("Currency", selection: $viewModel.selectedCurrency) {
                ForEach(CurrencyOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            if viewModel.selectedCurrency == .custom {
                TextField("Custom Symbol", text: $viewModel.customCurrencySymbol)
            }

            Picker("Time Rounding (Reports)", selection: $viewModel.selectedTimeRounding) {
                ForEach(TimeRoundingInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
        }
    }

    // MARK: - Idle Detection

    private var idleDetectionSection: some View {
        Section("Idle Detection") {
            Stepper(
                "Idle timeout: \(viewModel.idleTimeoutMinutes) minutes",
                value: $viewModel.idleTimeoutMinutes,
                in: 1...60
            )

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Subtract idle time from tracked time", isOn: $viewModel.subtractIdleTime)
                Text("When enabled, tracked time ends at the moment of last detected activity instead of when the pause occurs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Tracking reminder", isOn: $viewModel.trackingReminderEnabled)

            if viewModel.trackingReminderEnabled {
                DatePicker(
                    "Time",
                    selection: $viewModel.trackingReminderTime,
                    displayedComponents: .hourAndMinute
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(DayOfWeek.orderedWeekdays, id: \.weekday) { day in
                            let isSelected = viewModel.trackingReminderDays.contains(day.weekday)
                            Button {
                                if isSelected {
                                    viewModel.trackingReminderDays.remove(day.weekday)
                                } else {
                                    viewModel.trackingReminderDays.insert(day.weekday)
                                }
                            } label: {
                                Text(day.shortName)
                                    .font(.caption)
                                    .frame(width: 32, height: 24)
                            }
                            .buttonStyle(.bordered)
                            .tint(isSelected ? .accentColor : .secondary)
                        }
                    }
                }

                Text("Sends a reminder if no timer has been started by this time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        Section("Tags") {
            ForEach(viewModel.tags) { tag in
                if viewModel.editingTagId == tag.id {
                    editingTagRow
                } else {
                    tagRow(tag)
                }
            }

            if viewModel.isAddingTag {
                addingTagRow
            }

            if !viewModel.isAddingTag && viewModel.editingTagId == nil {
                Button {
                    viewModel.isAddingTag = true
                    viewModel.tagValidationError = nil
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
            }

            if let error = viewModel.tagValidationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .alert(
            "Delete tag '\(viewModel.tagToDelete?.name ?? "")'?",
            isPresented: Binding(
                get: { viewModel.tagToDelete != nil },
                set: { if !$0 { viewModel.tagToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let tag = viewModel.tagToDelete {
                    viewModel.deleteTag(id: tag.id)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.tagToDelete = nil
            }
        } message: {
            Text("This will remove it from all tasks.")
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 12, height: 12)

            Text(tag.name)

            Spacer()

            Button {
                viewModel.startEditing(tag: tag)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button {
                viewModel.tagToDelete = tag
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var editingTagRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: viewModel.editingTagColorHex))
                    .frame(width: 12, height: 12)

                TextField("Tag name", text: $viewModel.editingTagName)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    viewModel.saveEditingTag()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                .buttonStyle(.bordered)
            }

            TagColorPalette(selectedHex: $viewModel.editingTagColorHex)
        }
        .padding(.vertical, 4)
    }

    private var addingTagRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: viewModel.newTagColorHex))
                    .frame(width: 12, height: 12)

                TextField("Tag name", text: $viewModel.newTagName)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    viewModel.addTag()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    viewModel.isAddingTag = false
                    viewModel.newTagName = ""
                    viewModel.tagValidationError = nil
                }
                .buttonStyle(.bordered)
            }

            TagColorPalette(selectedHex: $viewModel.newTagColorHex)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Day of Week Helper

private struct DayOfWeek {
    let shortName: String
    let weekday: Int

    static let orderedWeekdays: [DayOfWeek] = [
        DayOfWeek(shortName: "Mon", weekday: 2),
        DayOfWeek(shortName: "Tue", weekday: 3),
        DayOfWeek(shortName: "Wed", weekday: 4),
        DayOfWeek(shortName: "Thu", weekday: 5),
        DayOfWeek(shortName: "Fri", weekday: 6),
        DayOfWeek(shortName: "Sat", weekday: 7),
        DayOfWeek(shortName: "Sun", weekday: 1),
    ]
}
