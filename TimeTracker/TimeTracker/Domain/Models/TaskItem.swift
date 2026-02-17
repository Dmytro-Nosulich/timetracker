import Foundation

struct TaskItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let taskDescription: String
    let createdAt: Date
    let isArchived: Bool
    let hourlyRate: Double?
    let tags: [TagItem]
    let timeEntries: [TimeEntryItem]
    let totalTrackedTime: TimeInterval
    let trackedTimeToday: TimeInterval
}
