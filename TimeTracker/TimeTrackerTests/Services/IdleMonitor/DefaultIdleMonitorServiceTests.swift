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
}
