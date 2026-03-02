import Foundation

struct TimeEntryItem: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let isManual: Bool
    let note: String?

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }
}
