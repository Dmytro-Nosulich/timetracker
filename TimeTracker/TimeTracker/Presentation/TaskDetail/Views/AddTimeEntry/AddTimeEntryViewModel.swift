import Foundation

@Observable
@MainActor
final class AddTimeEntryViewModel {
    enum Mode {
        case tracked
        case manual
    }

    let selectedDate: Date
    let existingRanges: [(id: UUID, start: Date, end: Date)]
    let onAddTracked: (Date, Date) -> Void
    let onAddManual: (Int, Int, String?) -> Void

    var mode: Mode = .tracked
    var startTime: Date
    var endTime: Date
    var manualHours: Int = 1
    var manualMinutes: Int = 0
    var manualNote: String = ""
    var showOverlapWarning: Bool = false
    var pendingSubmit: (() -> Void)?

    private let calendar = Calendar.current

    init(
        selectedDate: Date,
        existingRanges: [(id: UUID, start: Date, end: Date)],
        onAddTracked: @escaping (Date, Date) -> Void,
        onAddManual: @escaping (Int, Int, String?) -> Void
    ) {
        self.selectedDate = selectedDate
        self.existingRanges = existingRanges
        self.onAddTracked = onAddTracked
        self.onAddManual = onAddManual

        let startOfDay = calendar.startOfDay(for: selectedDate)
        self.startTime = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
        self.endTime = calendar.date(byAdding: .hour, value: 10, to: startOfDay) ?? startOfDay
    }

    /// Returns true if the entry was added (caller can dismiss). Returns false if overlap warning is shown.
    func submit() -> Bool {
        switch mode {
        case .tracked:
            if startTime >= endTime { return false }
            let overlaps = hasOverlappingTimeRanges(
                existing: existingRanges,
                newStart: startTime,
                newEnd: endTime
            )
            if overlaps {
                pendingSubmit = { [weak self] in
                    self?.performAddTracked()
                }
                showOverlapWarning = true
                return false
            } else {
                performAddTracked()
                return true
            }
        case .manual:
            if manualHours < 0 || manualMinutes < 0 { return false }
            if manualHours == 0 && manualMinutes == 0 { return false }
            performAddManual()
            return true
        }
    }

    func performAddTracked() {
        onAddTracked(startTime, endTime)
    }

    func performAddManual() {
        onAddManual(manualHours, manualMinutes, manualNote.isEmpty ? nil : manualNote)
    }

    func confirmOverlapAndProceed() {
        showOverlapWarning = false
        pendingSubmit?()
        pendingSubmit = nil
    }

    func cancelOverlap() {
        showOverlapWarning = false
        pendingSubmit = nil
    }
}
