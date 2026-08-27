import Testing
import Foundation
@testable import TimeTracker

/// Exercises the real listener on loopback, so these bind actual sockets on high ports
/// distinct from `MCPServerConfiguration.defaultPort` — the app itself may be running.
@MainActor
struct DefaultMCPServerServiceTests {

    private func makeService(port: Int, enabled: Bool = true) -> (DefaultMCPServerService, MockUserPreferencesService) {
        let prefs = MockUserPreferencesService()
        prefs.stubbedMCPServerPort = port
        prefs.stubbedMCPServerEnabled = enabled
        let service = DefaultMCPServerService(dataStore: MockMCPDataStore(), userPreferences: prefs)
        return (service, prefs)
    }

    @Test func startsStoppedAndReportsRunningOnceBound() async {
        let (service, _) = makeService(port: 8531)
        #expect(service.status == .stopped)

        await service.start()
        #expect(service.status == .running(port: 8531))

        await service.stop()
        #expect(service.status == .stopped)
    }

    @Test func startingTwiceKeepsTheOriginalListener() async {
        let (service, _) = makeService(port: 8532)
        await service.start()
        await service.start()

        #expect(service.status == .running(port: 8532))
        await service.stop()
    }

    /// The requirement: a busy port must never take the app down with it.
    @Test func aBusyPortFailsVisiblyInsteadOfCrashing() async {
        let (occupier, _) = makeService(port: 8533)
        await occupier.start()
        #expect(occupier.status == .running(port: 8533))

        let (blocked, _) = makeService(port: 8533)
        await blocked.start()

        guard case .failed(let reason) = blocked.status else {
            Issue.record("Expected a bind failure, got \(blocked.status)")
            await occupier.stop()
            return
        }
        // The reason is what the menu bar shows, so it has to name the actual problem.
        #expect(reason.contains("8533"))
        #expect(reason.contains("already in use"))

        // The first server is unaffected.
        #expect(occupier.status == .running(port: 8533))
        await occupier.stop()

        // Turning a failed server off clears the error rather than leaving it on screen.
        await blocked.stop()
        #expect(blocked.status == .stopped)
    }

    /// The Settings toggle restarts the server in place, so a stopped server must rebind.
    @Test func aStoppedServerCanBeStartedAgain() async {
        let (service, _) = makeService(port: 8535)
        await service.start()
        await service.stop()

        await service.start()
        #expect(service.status == .running(port: 8535))
        await service.stop()
    }

    @Test func stoppingAServerThatNeverStartedIsANoOp() async {
        let (service, _) = makeService(port: 8534)
        await service.stop()
        #expect(service.status == .stopped)
    }

    // MARK: - Preference-driven configuration

    /// The auto-start gate: AppDelegate calls start() unconditionally at launch, so the
    /// preference is what decides whether anything binds.
    @Test func startDoesNothingWhenDisabledInPreferences() async {
        let (service, _) = makeService(port: 8536, enabled: false)

        await service.start()

        #expect(service.status == .stopped)
    }

    @Test func applyPreferencesStartsAServerThatWasTurnedOn() async {
        let (service, prefs) = makeService(port: 8537, enabled: false)
        await service.start()
        #expect(service.status == .stopped)

        prefs.stubbedMCPServerEnabled = true
        await service.applyPreferences()

        #expect(service.status == .running(port: 8537))
        await service.stop()
    }

    @Test func applyPreferencesStopsAServerThatWasTurnedOff() async {
        let (service, prefs) = makeService(port: 8538)
        await service.start()
        #expect(service.status == .running(port: 8538))

        prefs.stubbedMCPServerEnabled = false
        await service.applyPreferences()

        #expect(service.status == .stopped)
    }

    @Test func applyPreferencesRebindsOnANewPort() async {
        let (service, prefs) = makeService(port: 8539)
        await service.start()
        #expect(service.status == .running(port: 8539))

        prefs.stubbedMCPServerPort = 8540
        await service.applyPreferences()

        #expect(service.status == .running(port: 8540))
        await service.stop()
    }

    /// The old port must actually be released, otherwise a rebind back onto it would fail.
    @Test func rebindingReleasesThePreviousPort() async {
        let (service, prefs) = makeService(port: 8541)
        await service.start()

        prefs.stubbedMCPServerPort = 8542
        await service.applyPreferences()
        #expect(service.status == .running(port: 8542))

        let (other, _) = makeService(port: 8541)
        await other.start()
        #expect(other.status == .running(port: 8541))

        await other.stop()
        await service.stop()
    }

    @Test func applyPreferencesIsANoOpWhenAlreadyRunningOnTheConfiguredPort() async {
        let (service, _) = makeService(port: 8543)
        await service.start()

        await service.applyPreferences()

        #expect(service.status == .running(port: 8543))
        await service.stop()
    }

    /// What the Settings screen's Retry button relies on: re-applying unchanged preferences
    /// after a bind failure tries the bind again.
    @Test func applyPreferencesRetriesAFailedBind() async {
        let (occupier, _) = makeService(port: 8544)
        await occupier.start()

        let (blocked, _) = makeService(port: 8544)
        await blocked.start()
        guard case .failed = blocked.status else {
            Issue.record("Expected a bind failure, got \(blocked.status)")
            await occupier.stop()
            return
        }

        await occupier.stop()
        await blocked.applyPreferences()

        #expect(blocked.status == .running(port: 8544))
        await blocked.stop()
    }
}
