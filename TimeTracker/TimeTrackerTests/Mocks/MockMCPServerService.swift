import Foundation
@testable import TimeTracker

@MainActor
final class MockMCPServerService: MCPServerService {
    var stubbedStatus: MCPServerStatus = .stopped

    var startCallCount = 0
    var stopCallCount = 0
    var applyPreferencesCallCount = 0

    var status: MCPServerStatus {
        stubbedStatus
    }

    func start() async {
        startCallCount += 1
    }

    func stop() async {
        stopCallCount += 1
    }

    func applyPreferences() async {
        applyPreferencesCallCount += 1
    }
}
