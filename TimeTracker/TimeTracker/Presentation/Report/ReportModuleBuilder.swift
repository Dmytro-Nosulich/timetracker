import SwiftUI

@MainActor
struct ReportModuleBuilder {
    static func build(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService
    ) -> some View {
        let pdfService = CoreGraphicsReportPDFService()
        let reportBuilder = DefaultReportBuilderService()
        let viewModel = ReportViewModel(
            localStorageService: localStorageService,
            userPreferencesService: userPreferencesService,
            pdfService: pdfService,
            reportBuilder: reportBuilder
        )
        return ReportView(viewModel: viewModel)
    }
}
