import Foundation

enum CrashRecoveryResult: Equatable {
    case noOpenEntry
    case resumedRecent(taskId: UUID)
    case staleEntry(entryId: UUID, taskId: UUID, startDate: Date)
}

@MainActor
protocol TimerService: AnyObject {
    var currentTaskId: UUID? { get }
    var sessionStartDate: Date? { get }
    var sessionElapsed: TimeInterval { get }
    var state: TimerState { get }

    func startTimer(for task: TaskItem)
    func pauseTimer()
    func resumeTimer()
    func pauseDueToInactivity(idleDuration: TimeInterval)
    @discardableResult
    func recoverFromCrashIfNeeded() -> CrashRecoveryResult
    func saveAndStop()
}
