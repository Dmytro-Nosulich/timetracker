import Foundation
@testable import TimeTracker

/// `@unchecked Sendable` because `ReportPDFService` is now `Sendable` and this mock's
/// recording properties are mutable — the same accommodation `MockUserPreferencesService`
/// makes. Tests drive it from one task at a time.
final class MockReportPDFService: ReportPDFService, @unchecked Sendable {
    var generatePDFCallCount = 0
    var generatePDFLastConfig: ReportPDFConfig?
    var stubbedPDFData: Data = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"

    func generatePDF(config: ReportPDFConfig) -> Data {
        generatePDFCallCount += 1
        generatePDFLastConfig = config
        return stubbedPDFData
    }
}
