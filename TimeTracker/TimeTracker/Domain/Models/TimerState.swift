import Foundation

enum TimerState: Equatable {
    case idle
    case running
    case pausedByUser
    case pausedByInactivity
}
