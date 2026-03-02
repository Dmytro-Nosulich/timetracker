import Foundation
@testable import TimeTracker

@MainActor
final class MockTimerService: TimerService {
    // MARK: - Stub Data

    var stubbedCurrentTaskId: UUID?
    var stubbedSessionStartDate: Date?
    var stubbedSessionElapsed: TimeInterval = 0
    var stubbedState: TimerState = .idle
    var stubbedCrashRecoveryResult: CrashRecoveryResult = .noOpenEntry

    var stubbedInactivityPauseDate: Date?
    var inactivityPauseDate: Date? { stubbedInactivityPauseDate }

    var currentTaskId: UUID? { stubbedCurrentTaskId }
    var sessionStartDate: Date? { stubbedSessionStartDate }
    var sessionElapsed: TimeInterval { stubbedSessionElapsed }
    var state: TimerState { stubbedState }

    // MARK: - Call Tracking

    var startTimerCallCount = 0
    var startTimerLastTask: TaskItem?
    var pauseTimerCallCount = 0
    var resumeTimerCallCount = 0
    var pauseDueToInactivityCallCount = 0
    var pauseDueToInactivityLastDuration: TimeInterval?
    var setPausedByUserCallCount = 0
    var recoverFromCrashCallCount = 0
    var saveAndStopCallCount = 0

    // MARK: - TimerService

    func startTimer(for task: TaskItem) {
        startTimerCallCount += 1
        startTimerLastTask = task
    }

    func pauseTimer() {
        pauseTimerCallCount += 1
    }

    func resumeTimer() {
        resumeTimerCallCount += 1
    }

    func pauseDueToInactivity(idleDuration: TimeInterval) {
        pauseDueToInactivityCallCount += 1
        pauseDueToInactivityLastDuration = idleDuration
    }

    func setPausedByUser() {
        setPausedByUserCallCount += 1
    }

    @discardableResult
    func recoverFromCrashIfNeeded() -> CrashRecoveryResult {
        recoverFromCrashCallCount += 1
        return stubbedCrashRecoveryResult
    }

    func saveAndStop() {
        saveAndStopCallCount += 1
    }
}
