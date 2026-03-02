import Foundation
@testable import TimeTracker

@MainActor
final class MockIdleMonitorService: IdleMonitorService {
    var startCallCount = 0

    func start() {
        startCallCount += 1
    }
}
