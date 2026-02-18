import Foundation
@testable import TimeTracker

final class MockReportPDFService: ReportPDFService {
    var generatePDFCallCount = 0
    var generatePDFLastConfig: ReportPDFConfig?
    var stubbedPDFData: Data = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"

    func generatePDF(config: ReportPDFConfig) -> Data {
        generatePDFCallCount += 1
        generatePDFLastConfig = config
        return stubbedPDFData
    }
}
