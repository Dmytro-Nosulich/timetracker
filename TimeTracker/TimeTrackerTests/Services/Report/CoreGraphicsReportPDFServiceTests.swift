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
        showAmountColumn: Bool = false,
        totalTime: String = "0h 00m",
        totalAmount: String? = nil,
        totalRate: String? = nil
    ) -> ReportPDFConfig {
        ReportPDFConfig(
            businessName: businessName,
            startDate: Date(),
            endDate: Date(),
            generatedDate: Date(),
            tasks: tasks,
            currencySymbol: "$",
            showAmountColumn: showAmountColumn,
            totalTime: totalTime,
            totalAmount: totalAmount,
            totalRate: totalRate
        )
    }

    private func makeTaskRow(
        formattedDate: String? = nil,
        title: String = "Task",
        formattedTime: String = "1h 00m",
        formattedAmount: String? = nil
    ) -> ReportPDFTaskRow {
        ReportPDFTaskRow(
            formattedDate: formattedDate,
            title: title,
            formattedTime: formattedTime,
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
            makeTaskRow(formattedDate: "01.03.2026", title: "Website Redesign", formattedTime: "24h 30m"),
            makeTaskRow(formattedDate: "02.03.2026", title: "API Integration", formattedTime: "12h 15m")
        ]
        let config = makeConfig(tasks: tasks, totalTime: "36h 45m")
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
        #expect(data.count > 100)
    }

    @Test func generatePDFWithAmountColumn() {
        let service = makeService()
        let tasks = [
            makeTaskRow(
                formattedDate: "01.03.2026",
                title: "Website Redesign",
                formattedTime: "24h 30m",
                formattedAmount: "$1,225.00"
            ),
            makeTaskRow(
                formattedDate: "02.03.2026",
                title: "Meetings",
                formattedTime: "5h 00m",
                formattedAmount: nil
            )
        ]
        let config = makeConfig(
            tasks: tasks,
            showAmountColumn: true,
            totalTime: "29h 30m",
            totalAmount: "$1,225.00",
            totalRate: "$50/h"
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
            makeTaskRow(formattedDate: "01.03.2026", title: "Task \(i)", formattedTime: "\(i)h 00m")
        }
        let config = makeConfig(tasks: tasks, totalTime: "1225h 00m")
        let data = service.generatePDF(config: config)
        #expect(!data.isEmpty)
    }
}
