import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var viewModel: TaskDetailViewModel

    @State private var showTagPicker = false

    var body: some View {
        Group {
            if viewModel.task == nil {
                ContentUnavailableView(
                    "Task Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The task could not be loaded.")
                )
                .frame(minWidth: 500, minHeight: 600)
            } else {
                content
            }
        }
        .navigationTitle("Task Details — \(viewModel.title)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid)
            }
        }
        .confirmationDialog("You have unsaved changes. Discard?", isPresented: $viewModel.showCancelConfirmation) {
            Button("Discard", role: .destructive) {
                viewModel.confirmCancelDiscard()
            }
            Button("Keep Editing", role: .cancel) {
                viewModel.cancelDiscardAndKeepEditing()
            }
        } message: {
            Text("Your changes will be lost.")
        }
        .onExitCommand {
            viewModel.cancel()
        }
        .confirmationDialog("Delete this time entry?", isPresented: Binding(
            get: { viewModel.entryToDelete != nil },
            set: { if !$0 { viewModel.entryToDelete = nil } }
        ), presenting: viewModel.entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                viewModel.deleteTimeEntry(entry)
            }
            Button("Cancel", role: .cancel) {
                viewModel.entryToDelete = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showAddTimeEntry) {
            AddTimeEntryView(
                viewModel: AddTimeEntryViewModel(
                    selectedDate: viewModel.selectedDate,
                    existingRanges: viewModel.existingRangesForSelectedDay(),
                    onAddTracked: { start, end in
                        viewModel.addTimeEntryTracked(startDate: start, endDate: end)
                    },
                    onAddManual: { hours, minutes, note in
                        viewModel.addTimeEntryManual(hours: hours, minutes: minutes, note: note, for: viewModel.selectedDate)
                    }
                )
            )
        }
        .sheet(isPresented: $viewModel.showEditTimeEntry) {
            if let entry = viewModel.entryToEdit {
                EditTimeEntryView(
                    viewModel: EditTimeEntryViewModel(
                        entry: entry,
                        selectedDate: viewModel.selectedDate,
                        existingRanges: viewModel.existingRangesForSelectedDay(excludingEntryId: entry.id),
                        onSave: { start, end in
                            viewModel.updateTimeEntryTracked(entry, startDate: start, endDate: end)
                        },
                        onSaveManual: { hours, minutes, note in
                            viewModel.updateTimeEntryManual(entry, hours: hours, minutes: minutes, note: note)
                        }
                    )
                )
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleSection
                descriptionSection
                tagsSection
                hourlyRateSection
                totalTrackedSection
                calendarSection
                timeEntriesSection
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Title")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Task title", text: Binding(
                get: { viewModel.title },
                set: { viewModel.title = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { viewModel.taskDescription },
                set: { viewModel.taskDescription = $0 }
            ))
            .frame(minHeight: 60)
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(viewModel.taskTags, id: \.id) { tag in
                    RemovableTagChip(tag: tag) {
                        viewModel.removeTag(tag)
                    }
                }
                Button {
                    showTagPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .popover(isPresented: $showTagPicker) {
            TagPickerView(
                allTags: viewModel.allTags,
                taskTags: viewModel.taskTags,
                onSelect: { tag in
                    viewModel.addTag(tag)
                    showTagPicker = false
                },
                onCreate: { name, colorHex in
                    viewModel.createAndAddTag(name: name, colorHex: colorHex)
                    showTagPicker = false
                }
            )
            .frame(width: 250, height: 300)
        }
    }

    private var hourlyRateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hourly Rate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(viewModel.currencySymbolDisplay)
                    .foregroundStyle(.secondary)
                TextField("0.00", text: Binding(
                    get: { viewModel.hourlyRateString },
                    set: { viewModel.hourlyRateString = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var totalTrackedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total tracked")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text((viewModel.task?.totalTrackedTime ?? 0).formattedHoursMinutes)
                .font(.body)
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Calendar")
                .font(.headline)

            CalendarHeatmapView(
                displayMonth: viewModel.displayMonth,
                selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ),
                hoursForDay: { viewModel.hoursForDay($0) },
                onMonthChange: { viewModel.navigateMonth(by: $0) }
            )
        }
    }

    private var timeEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Day: \(formattedSelectedDate)")
                .font(.headline)

            let entries = viewModel.entriesForDay(viewModel.selectedDate)
            let total = viewModel.totalForSelectedDay()

            if entries.isEmpty {
                Text("No time entries for this day.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(entries, id: \.id) { entry in
                    TimeEntryRowView(
                        entry: entry,
                        onEdit: { viewModel.showEditSheet(for: entry) },
                        onDelete: { viewModel.showDeleteConfirmation(for: entry) }
                    )
                }

                HStack {
                    Spacer()
                    Text("Day total: \(total.formattedHoursMinutes)")
                        .fontWeight(.medium)
                }
            }

            Button {
                viewModel.showAddTimeEntry = true
            } label: {
                Label("Add Time Entry", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: viewModel.selectedDate)
    }
}

// MARK: - Removable Tag Chip

private struct RemovableTagChip: View {
    let tag: TagEntity
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 8, height: 8)
            Text(tag.name)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Tag Picker

private struct TagPickerView: View {
    let allTags: [TagEntity]
    let taskTags: [TagEntity]
    let onSelect: (TagEntity) -> Void
    let onCreate: (String, String) -> Void

    @State private var newTagName = ""
    @State private var newTagColor = "007AFF"

    private let presetColors = ["FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "007AFF", "5856D6", "AF52DE"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Tag")
                .font(.headline)

            if !allTags.isEmpty {
                let availableTags = allTags.filter { t in !taskTags.contains(where: { $0.id == t.id }) }
                if availableTags.isEmpty {
                    Text("All tags are already added.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List(availableTags, id: \.id) { tag in
                        Button {
                            onSelect(tag)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(tag.name)
                            }
                        }
                    }
                }
            }

            Divider()

            Text("Create new tag")
                .font(.subheadline)

            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)

            HStack {
                ForEach(presetColors, id: \.self) { hex in
                    Button {
                        newTagColor = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(newTagColor == hex ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Create & Add") {
                onCreate(newTagName, newTagColor)
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

// MARK: - Time Entry Row

private struct TimeEntryRowView: View {
    let entry: TimeEntryEntity
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack {
            if entry.isManual {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manual entry \(entry.duration.formattedHoursMinutes)")
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(timeRangeString)
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var timeRangeString: String {
        let start = Self.timeFormatter.string(from: entry.startDate)
        let end = entry.endDate.map { Self.timeFormatter.string(from: $0) } ?? "—"
        return "\(start) – \(end) (\(entry.duration.formattedHoursMinutes))"
    }
}
