import Foundation
@testable import TimeTracker

final class MockDateProvider: DateProvider, @unchecked Sendable {
    var currentDate: Date = Date()

    func now() -> Date {
        currentDate
    }
}
