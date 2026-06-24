import Foundation

enum TaskReminderMode: String, CaseIterable {
    case currentSession
    case today
    case allTime

    var displayName: String {
        switch self {
        case .currentSession: return "Current session"
        case .today: return "Today"
        case .allTime: return "All time"
        }
    }
}
