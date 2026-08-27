import AppKit
import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @State private var didCopyServerURL = false
    @State private var didCopyConfigJSON = false
    @State private var showsConfigJSON = false

    var body: some View {
        Form {
            generalSection
            idleDetectionSection
            notificationsSection
            mcpServerSection
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

            LabeledContent("Target daily hours (Heatmap)") {
                HStack(spacing: 8) {
                    Text("\(viewModel.targetDailyHours)h")
                        .bold()
                        .monospacedDigit()
                    Stepper("", value: $viewModel.targetDailyHours, in: 1...24)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Idle Detection

    private var idleDetectionSection: some View {
        Section("Idle Detection") {
            LabeledContent("Idle timeout") {
                HStack(spacing: 8) {
                    Text("\(viewModel.idleTimeoutMinutes) minutes")
                        .bold()
                        .monospacedDigit()
                    Stepper("", value: $viewModel.idleTimeoutMinutes, in: 1...60)
                        .labelsHidden()
                }
            }

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

    // MARK: - MCP Server

    private var mcpServerSection: some View {
        Section("MCP Server") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Enable MCP server", isOn: $viewModel.mcpServerEnabled)
                Text("Lets an AI assistant read your tracked time while this app is running. Listens on this Mac only — never on the network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.mcpServerEnabled {
                portRow
                statusRow
                serverURLRow
                configJSONRow
            }
        }
    }

    private var portRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Port") {
                HStack(spacing: 8) {
                    TextField("Port", text: $viewModel.mcpServerPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .monospacedDigit()
                        .onSubmit { viewModel.applyPort() }

                    Button("Apply") {
                        viewModel.applyPort()
                    }
                    .disabled(!viewModel.hasPendingPortChange)
                }
            }

            if let error = viewModel.portValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusRow: some View {
        LabeledContent("Status") {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(viewModel.mcpServerStatusText)
                    .foregroundStyle(viewModel.mcpServerStatusIsError ? Color.red : Color.primary)

                if viewModel.mcpServerStatusIsError {
                    Button("Retry") {
                        viewModel.retryMCPServer()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var statusColor: Color {
        if viewModel.mcpServerStatusIsError { return .red }
        return viewModel.mcpServerIsRunning ? .green : .secondary
    }

    /// The address to register, for clients configured by URL or by a CLI command.
    private var serverURLRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("URL") {
                HStack(spacing: 8) {
                    Text(viewModel.mcpServerURL)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    Button {
                        copy(viewModel.mcpServerURL, marking: $didCopyServerURL)
                    } label: {
                        Image(systemName: didCopyServerURL ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy the registration URL")
                }
            }

            Text("Register this URL with your AI client, or copy the configuration below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    /// The same connection details as a paste-ready config block, for the many clients that
    /// are set up by editing a JSON file rather than by running a command. Collapsed by
    /// default — it's needed once per client, and the section is already tall.
    private var configJSONRow: some View {
        DisclosureGroup("Configuration for other AI clients", isExpanded: $showsConfigJSON) {
            VStack(alignment: .leading, spacing: 6) {
                // The copy button lives in the content rather than the disclosure's label:
                // a button in the label competes with the label's own tap-to-expand gesture,
                // and copying is only wanted once the block is open anyway.
                HStack {
                    Text("Paste into your client's MCP config file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        copy(viewModel.mcpServerConfigJSON, marking: $didCopyConfigJSON)
                    } label: {
                        Label(
                            didCopyConfigJSON ? "Copied" : "Copy",
                            systemImage: didCopyConfigJSON ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy the configuration JSON")
                }

                Text(viewModel.mcpServerConfigJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                    )
            }
            .padding(.top, 4)
        }
    }

    /// Writes to the pasteboard and flips the button to a checkmark for two seconds. Lives
    /// in the view rather than the view model so unit tests never touch the real clipboard.
    private func copy(_ string: String, marking didCopy: Binding<Bool>) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        didCopy.wrappedValue = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy.wrappedValue = false
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
