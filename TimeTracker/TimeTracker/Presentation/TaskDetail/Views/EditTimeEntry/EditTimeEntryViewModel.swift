import Foundation
import SwiftData

@Observable
@MainActor
final class EditTimeEntryViewModel {
    let entry: TimeEntryEntity
    let selectedDate: Date
    let existingRanges: [(id: UUID, start: Date, end: Date)]
    let onSave: (Date, Date) -> Void
    let onSaveManual: (Int, Int, String?) -> Void

    var startTime: Date
    var endTime: Date
    var manualHours: Int
    var manualMinutes: Int
    var manualNote: String
    var showOverlapWarning: Bool = false
    var pendingSave: (() -> Void)?

    private let calendar = Calendar.current

    init(
        entry: TimeEntryEntity,
        selectedDate: Date,
        existingRanges: [(id: UUID, start: Date, end: Date)],
        onSave: @escaping (Date, Date) -> Void,
        onSaveManual: @escaping (Int, Int, String?) -> Void
    ) {
        self.entry = entry
        self.selectedDate = selectedDate
        self.existingRanges = existingRanges
        self.onSave = onSave
        self.onSaveManual = onSaveManual

        if entry.isManual {
            let totalMinutes = Int(entry.duration) / 60
            self.manualHours = totalMinutes / 60
            self.manualMinutes = totalMinutes % 60
            self.manualNote = entry.note ?? ""
            self.startTime = entry.startDate
            self.endTime = entry.endDate ?? entry.startDate
        } else {
            self.startTime = entry.startDate
            self.endTime = entry.endDate ?? entry.startDate
            self.manualHours = 0
            self.manualMinutes = 0
            self.manualNote = ""
        }
    }

    /// Returns true if saved (caller can dismiss). Returns false if overlap warning is shown.
    func save() -> Bool {
        if entry.isManual {
            if manualHours < 0 || manualMinutes < 0 { return false }
            if manualHours == 0 && manualMinutes == 0 { return false }
            onSaveManual(manualHours, manualMinutes, manualNote.isEmpty ? nil : manualNote)
            return true
        } else {
            if startTime >= endTime { return false }
            let overlaps = hasOverlappingTimeRanges(
                existing: existingRanges,
                newStart: startTime,
                newEnd: endTime,
                excludingId: entry.id
            )
            if overlaps {
                pendingSave = { [weak self] in
                    guard let self else { return }
                    self.onSave(self.startTime, self.endTime)
                }
                showOverlapWarning = true
                return false
            } else {
                onSave(startTime, endTime)
                return true
            }
        }
    }

    func confirmOverlapAndProceed() {
        showOverlapWarning = false
        pendingSave?()
        pendingSave = nil
    }

    func cancelOverlap() {
        showOverlapWarning = false
        pendingSave = nil
    }
}
