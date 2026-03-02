import Foundation

struct ReportTaskRowItem: Identifiable {
    let id: UUID
    let title: String
    let timeForPeriod: TimeInterval
    let roundedTime: TimeInterval
    let hourlyRate: Double?
    let amount: Double?
    var isSelected: Bool
}
