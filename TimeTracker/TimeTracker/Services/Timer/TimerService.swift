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
    /// Set when state becomes `.pausedByInactivity`; cleared when leaving that state. Used for "Inactive for Xm" / "paused X minutes ago".
    var inactivityPauseDate: Date? { get }

    func startTimer(for task: TaskItem)
    func pauseTimer()
    func resumeTimer()
    func pauseDueToInactivity(idleDuration: TimeInterval)
    /// Changes state from `.pausedByInactivity` to `.pausedByUser` without creating a new entry (e.g. "Keep Paused" in Welcome back dialog).
    func setPausedByUser()
    @discardableResult
    func recoverFromCrashIfNeeded() -> CrashRecoveryResult
    func saveAndStop()
}
