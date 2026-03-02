import Foundation

struct ReportPDFConfig {
    let businessName: String
    let startDate: Date
    let endDate: Date
    let generatedDate: Date
    let tasks: [ReportPDFTaskRow]
    let currencySymbol: String
    let showAmountColumn: Bool
    let totalTime: String
    let totalAmount: String?
    let totalRate: String?
}

struct ReportPDFTaskRow {
    let formattedDate: String?
    let title: String
    let formattedTime: String
    let formattedAmount: String?
}

protocol ReportPDFService {
    func generatePDF(config: ReportPDFConfig) -> Data
}
