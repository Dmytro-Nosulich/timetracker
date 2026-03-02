import Foundation
import SwiftData

@Model
final class TimeEntryEntity {
    var id: UUID
    var task: TaskEntity?
    var startDate: Date
    var endDate: Date?
    var isManual: Bool
    var note: String?

    init(task: TaskEntity, startDate: Date, endDate: Date? = nil, isManual: Bool = false, note: String? = nil) {
        self.id = UUID()
        self.task = task
        self.startDate = startDate
        self.endDate = endDate
        self.isManual = isManual
        self.note = note
    }
}

extension TimeEntryEntity {

	var duration: TimeInterval {
		let end = endDate ?? Date()
		return end.timeIntervalSince(startDate)
	}
}
