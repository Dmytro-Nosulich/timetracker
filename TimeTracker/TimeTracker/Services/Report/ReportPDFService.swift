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

/// `Sendable` so `save_report_pdf` can hold one off the main actor — the same reason
/// `UserPreferencesService` is. It constrains conformers, not callers, so the Report
/// screen is unaffected. Note the rendering itself is still hopped onto the main actor by
/// that tool, because the implementation draws with AppKit types.
protocol ReportPDFService: Sendable {
    func generatePDF(config: ReportPDFConfig) -> Data
}
