import Foundation

struct ReportPDFConfig {
    let businessName: String
    let startDate: Date
    let endDate: Date
    let generatedDate: Date
    let tasks: [ReportPDFTaskRow]
    let currencySymbol: String
    let showRateColumns: Bool
    let totalTime: String
    let totalAmount: String?
}

struct ReportPDFTaskRow {
    let title: String
    let formattedTime: String
    let formattedRate: String?
    let formattedAmount: String?
}

protocol ReportPDFService {
    func generatePDF(config: ReportPDFConfig) -> Data
}
