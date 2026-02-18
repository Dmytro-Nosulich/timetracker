import Foundation
import SwiftData

@Observable
@MainActor
final class TaskDetailViewModel {
    private let taskId: UUID
    private let modelContainer: ModelContainer
    private let childContext: ModelContext
    private let coordinator: TaskDetailCoordinator
    private let currencySymbol: String
    private let onClose: () -> Void

    var task: TaskEntity?
    var selectedDate: Date
    var displayMonth: Date
    var hasUnsavedChanges: Bool = false
    var showCancelConfirmation: Bool = false
    var showAddTimeEntry: Bool = false
    var showEditTimeEntry: Bool = false
    var entryToEdit: TimeEntryEntity?
    var entryToDelete: TimeEntryEntity?
    var showOverlapWarning: Bool = false
    var overlapWarningAction: (() -> Void)?

    var title: String {
        get { task?.title ?? "" }
        set {
            task?.title = newValue
            markDirty()
        }
    }

    var taskDescription: String {
        get { task?.taskDescription ?? "" }
        set {
            task?.taskDescription = newValue
            markDirty()
        }
    }

    var hourlyRateString: String {
        get {
            guard let rate = task?.hourlyRate else { return "" }
            return formatRate(rate)
        }
        set {
            let parsed = parseRate(newValue)
            task?.hourlyRate = parsed
            markDirty()
        }
    }

    var isValid: Bool {
        guard let t = task else { return false }
        return !t.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var allTags: [TagEntity] {
        let descriptor = FetchDescriptor<TagEntity>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? childContext.fetch(descriptor)) ?? []
    }

    var taskTags: [TagEntity] {
        task?.tags ?? []
    }

    var currencySymbolDisplay: String {
        currencySymbol
    }

    init(
        taskId: UUID,
        modelContainer: ModelContainer,
        coordinator: TaskDetailCoordinator,
        currencySymbol: String,
        onClose: @escaping () -> Void
    ) {
        self.taskId = taskId
        self.modelContainer = modelContainer
        self.coordinator = coordinator
        self.currencySymbol = currencySymbol
        self.onClose = onClose

        let ctx = ModelContext(modelContainer)
        ctx.autosaveEnabled = false
        self.childContext = ctx

        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate<TaskEntity> { $0.id == taskId }
        )
        let fetchedTask = try? childContext.fetch(descriptor).first
        self.task = fetchedTask

        let calendar = Calendar.current
        if let t = fetchedTask, !t.timeEntries.isEmpty {
            let mostRecent = t.timeEntries.max(by: { ($0.endDate ?? $0.startDate) < ($1.endDate ?? $1.startDate) })!
            let date = mostRecent.endDate ?? mostRecent.startDate
            self.displayMonth = calendar.startOfMonth(for: date)
            self.selectedDate = calendar.startOfDay(for: date)
        } else {
            self.displayMonth = calendar.startOfMonth(for: Date())
            self.selectedDate = calendar.startOfDay(for: Date())
        }
    }

    func markDirty() {
        hasUnsavedChanges = true
        coordinator.hasUnsavedChanges = true
    }

    func save() {
        guard isValid else { return }
        task?.title = task?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try? childContext.save()
        coordinator.close()
        onClose()
    }

    func cancel() {
        if hasUnsavedChanges {
            showCancelConfirmation = true
        } else {
            coordinator.close()
            onClose()
        }
    }

    func confirmCancelDiscard() {
        showCancelConfirmation = false
        coordinator.close()
        onClose()
    }

    func cancelDiscardAndKeepEditing() {
        showCancelConfirmation = false
    }

    func removeTag(_ tag: TagEntity) {
        task?.tags.removeAll { $0.id == tag.id }
        tag.tasks.removeAll { $0.id == task?.id }
        markDirty()
    }

    func addTag(_ tag: TagEntity) {
        guard let t = task, !t.tags.contains(where: { $0.id == tag.id }) else { return }
        t.tags.append(tag)
        if !tag.tasks.contains(where: { $0.id == t.id }) {
            tag.tasks.append(t)
        }
        markDirty()
    }

    func createAndAddTag(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existing = allTags.first { $0.name.lowercased() == trimmed.lowercased() }
        if let tag = existing {
            addTag(tag)
        } else {
            let tag = TagEntity(name: trimmed, colorHex: colorHex)
            childContext.insert(tag)
            addTag(tag)
        }
    }

    func entriesForDay(_ date: Date) -> [TimeEntryEntity] {
        guard let t = task else { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return t.timeEntries.filter { entry in
            let entryEnd = entry.endDate ?? entry.startDate
            return entry.startDate < endOfDay && entryEnd > startOfDay
        }.sorted { $0.startDate < $1.startDate }
    }

    func hoursForDay(_ date: Date) -> TimeInterval {
        entriesForDay(date).reduce(0) { $0 + $1.duration }
    }

    func totalForSelectedDay() -> TimeInterval {
        entriesForDay(selectedDate).reduce(0) { $0 + $1.duration }
    }

    func navigateMonth(by delta: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayMonth) {
            displayMonth = newMonth
        }
    }

    func addTimeEntryTracked(startDate: Date, endDate: Date) {
        guard let t = task else { return }
        let entry = TimeEntryEntity(task: t, startDate: startDate, endDate: endDate, isManual: false)
        childContext.insert(entry)
        t.timeEntries.append(entry)
        markDirty()
    }

    func addTimeEntryManual(hours: Int, minutes: Int, note: String?, for date: Date) {
        guard let t = task else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let durationSeconds = TimeInterval(hours * 3600 + minutes * 60)
        let endDate = startOfDay.addingTimeInterval(durationSeconds)
        let entry = TimeEntryEntity(task: t, startDate: startOfDay, endDate: endDate, isManual: true, note: note?.isEmpty == true ? nil : note)
        childContext.insert(entry)
        t.timeEntries.append(entry)
        markDirty()
    }

    func updateTimeEntryTracked(_ entry: TimeEntryEntity, startDate: Date, endDate: Date) {
        entry.startDate = startDate
        entry.endDate = endDate
        markDirty()
    }

    func updateTimeEntryManual(_ entry: TimeEntryEntity, hours: Int, minutes: Int, note: String?) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entry.startDate)
        let durationSeconds = TimeInterval(hours * 3600 + minutes * 60)
        let endDate = startOfDay.addingTimeInterval(durationSeconds)
        entry.startDate = startOfDay
        entry.endDate = endDate
        entry.note = note?.isEmpty == true ? nil : note
        markDirty()
    }

    func deleteTimeEntry(_ entry: TimeEntryEntity) {
        entry.task?.timeEntries.removeAll { $0.id == entry.id }
        childContext.delete(entry)
        markDirty()
        entryToDelete = nil
    }

    func showEditSheet(for entry: TimeEntryEntity) {
        entryToEdit = entry
        showEditTimeEntry = true
    }

    func showDeleteConfirmation(for entry: TimeEntryEntity) {
        entryToDelete = entry
    }

    func existingRangesForSelectedDay(excludingEntryId: UUID? = nil) -> [(id: UUID, start: Date, end: Date)] {
        let entries = entriesForDay(selectedDate)
        return entries.compactMap { entry in
            if let exclude = excludingEntryId, entry.id == exclude { return nil }
            let end = entry.endDate ?? entry.startDate
            return (entry.id, entry.startDate, end)
        }
    }
}

// MARK: - Helpers

private extension TaskDetailViewModel {
    func formatRate(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func parseRate(_ string: String) -> Double? {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
