import Foundation
import SwiftData

@Model
final class TaskEntity {
    var id: UUID
    var title: String
    var taskDescription: String
    var createdAt: Date
    var isArchived: Bool
    var hourlyRate: Double?

    @Relationship(inverse: \TagEntity.tasks)
    var tags: [TagEntity]

    @Relationship(deleteRule: .cascade)
    var timeEntries: [TimeEntryEntity]

    init(title: String, taskDescription: String = "", hourlyRate: Double? = nil) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.createdAt = Date()
        self.isArchived = false
        self.hourlyRate = hourlyRate
        self.tags = []
        self.timeEntries = []
    }
}

extension TaskEntity {

	var totalTrackedTime: TimeInterval {
		timeEntries.reduce(0) { $0 + $1.duration }
	}

	var trackedTimeToday: TimeInterval {
		let calendar = Calendar.current
		let startOfDay = calendar.startOfDay(for: Date())
		return trackedTime(from: startOfDay, to: Date())
	}

	func trackedTime(from startDate: Date, to endDate: Date) -> TimeInterval {
		timeEntries
			.filter { entry in
				let entryEnd = entry.endDate ?? Date()
				return entry.startDate < endDate && entryEnd > startDate
			}
			.reduce(0) { total, entry in
				let effectiveStart = max(entry.startDate, startDate)
				let effectiveEnd = min(entry.endDate ?? Date(), endDate)
				return total + effectiveEnd.timeIntervalSince(effectiveStart)
			}
	}

	var activeTimeEntry: TimeEntryEntity? {
		timeEntries.first { $0.endDate == nil }
	}
}
