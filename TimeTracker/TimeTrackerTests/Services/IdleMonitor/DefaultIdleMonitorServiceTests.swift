import AppKit
import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct DefaultIdleMonitorServiceTests {

    private func makeTimerMock() -> MockTimerService {
        MockTimerService()
    }

    private func makePreferencesMock() -> MockUserPreferencesService {
        let prefs = MockUserPreferencesService()
        prefs.stubbedIdleTimeoutMinutes = 10
        return prefs
    }

    private func makeStorageMock() -> MockLocalStorageService {
        MockLocalStorageService()
    }

    private func makeService(
        timer: MockTimerService? = nil,
        preferences: MockUserPreferencesService? = nil,
        storage: MockLocalStorageService? = nil
    ) -> (DefaultIdleMonitorService, MockTimerService, MockUserPreferencesService, MockLocalStorageService) {
        let t = timer ?? makeTimerMock()
        let p = preferences ?? makePreferencesMock()
        let s = storage ?? makeStorageMock()
        let service = DefaultIdleMonitorService(timerService: t, userPreferences: p, localStorage: s)
        return (service, t, p, s)
    }

    @Test func startDoesNotCrash() {
        let (service, _, _, _) = makeService()
        service.start()
        // Verifies start() runs without crashing and sets up timer + observers
    }

    @Test func pausesTimerWhenSystemWillSleep() async throws {
        let timer = makeTimerMock()
        timer.stubbedState = .running
        let (service, _, _, _) = makeService(timer: timer)
        service.start()

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: NSWorkspace.shared
        )

        // The notification handler hops onto the main queue asynchronously,
        // so give it a chance to run before asserting.
        for _ in 0..<50 where timer.pauseDueToInactivityCallCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(timer.pauseDueToInactivityCallCount == 1)
    }
}
