import Testing
import Foundation
@testable import TimeTracker

/// Exercises the real listener on loopback, so these bind actual sockets on high ports
/// distinct from `MCPServerConfiguration.defaultPort` — the app itself may be running.
@MainActor
struct DefaultMCPServerServiceTests {

    private func makeService(port: Int) -> DefaultMCPServerService {
        DefaultMCPServerService(dataStore: MockMCPDataStore(), port: port)
    }

    @Test func startsStoppedAndReportsRunningOnceBound() async {
        let service = makeService(port: 8531)
        #expect(service.status == .stopped)

        await service.start()
        #expect(service.status == .running(port: 8531))

        await service.stop()
        #expect(service.status == .stopped)
    }

    @Test func startingTwiceKeepsTheOriginalListener() async {
        let service = makeService(port: 8532)
        await service.start()
        await service.start()

        #expect(service.status == .running(port: 8532))
        await service.stop()
    }

    /// The requirement: a busy port must never take the app down with it.
    @Test func aBusyPortFailsVisiblyInsteadOfCrashing() async {
        let occupier = makeService(port: 8533)
        await occupier.start()
        #expect(occupier.status == .running(port: 8533))

        let blocked = makeService(port: 8533)
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

    /// Step 3's toggle restarts the server in place, so a stopped server must rebind.
    @Test func aStoppedServerCanBeStartedAgain() async {
        let service = makeService(port: 8535)
        await service.start()
        await service.stop()

        await service.start()
        #expect(service.status == .running(port: 8535))
        await service.stop()
    }

    @Test func stoppingAServerThatNeverStartedIsANoOp() async {
        let service = makeService(port: 8534)
        await service.stop()
        #expect(service.status == .stopped)
    }
}
