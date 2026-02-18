import Testing
import Foundation
@testable import TimeTracker

struct CoreGraphicsReportPDFServiceTests {

    private func makeService() -> CoreGraphicsReportPDFService {
        CoreGraphicsReportPDFService()
    }

    private func makeConfig(
        businessName: String = "Test Business",
        tasks: [ReportPDFTaskRow] = [],
        showRateColumns: Bool = false,
        totalTime: String = "0h 00m",
        totalAmount: String? = nil
    ) -> ReportPDFConfig {
        ReportPDFConfig(
            businessName: businessName,
            startDate: Date(),
            endDate: Date(),
            generatedDate: Date(),
            tasks: tasks,
            currencySymbol: "$",
            showRateColumns: showRateColumns,
            totalTime: totalTime,
            totalAmount: totalAmount
        )
    }

    private func makeTaskRow(
        title: String = "Task",
        formattedTime: String = "1h 00m",
        formattedRate: String? = nil,
        formattedAmount: String? = nil
    ) -> ReportPDFTaskRow {
        ReportPDFTaskRow(
            title: title,
            formattedTime: formattedTime,
            formattedRate: formattedRate,
            formattedAmount: formattedAmount
        )
    }

    @Test func generatePDFReturnsNonEmptyData() {
        let service = makeService()
        let config = makeConfig()
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
    }

    @Test func generatePDFStartsWithPDFHeader() {
        let service = makeService()
        let config = makeConfig()
        let data = service.generatePDF(config: config)
        let prefix = String(data: data.prefix(5), encoding: .ascii) ?? ""
        #expect(prefix == "%PDF-")
    }

    @Test func generatePDFWithTasks() {
        let service = makeService()
        let tasks = [
            makeTaskRow(title: "Website Redesign", formattedTime: "24h 30m"),
            makeTaskRow(title: "API Integration", formattedTime: "12h 15m")
        ]
        let config = makeConfig(tasks: tasks, totalTime: "36h 45m")
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
        #expect(data.count > 100)
    }

    @Test func generatePDFWithRateColumns() {
        let service = makeService()
        let tasks = [
            makeTaskRow(
                title: "Website Redesign",
                formattedTime: "24h 30m",
                formattedRate: "$50/h",
                formattedAmount: "$1,225.00"
            ),
            makeTaskRow(
                title: "Meetings",
                formattedTime: "5h 00m",
                formattedRate: nil,
                formattedAmount: nil
            )
        ]
        let config = makeConfig(
            tasks: tasks,
            showRateColumns: true,
            totalTime: "29h 30m",
            totalAmount: "$1,225.00"
        )
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
    }

    @Test func generatePDFWithEmptyBusinessName() {
        let service = makeService()
        let config = makeConfig(businessName: "")
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
    }

    @Test func generatePDFWithManyTasks() {
        let service = makeService()
        let tasks = (0..<50).map { i in
            makeTaskRow(title: "Task \(i)", formattedTime: "\(i)h 00m")
        }
        let config = makeConfig(tasks: tasks, totalTime: "1225h 00m")
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
    }
}
