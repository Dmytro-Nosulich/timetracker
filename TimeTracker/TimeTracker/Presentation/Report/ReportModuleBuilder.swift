import SwiftUI

@MainActor
struct ReportModuleBuilder {
    static func build(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService
    ) -> some View {
        let pdfService = CoreGraphicsReportPDFService()
        let viewModel = ReportViewModel(
            localStorageService: localStorageService,
            userPreferencesService: userPreferencesService,
            pdfService: pdfService
        )
        return ReportView(viewModel: viewModel)
    }
}
