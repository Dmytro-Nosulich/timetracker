import SwiftUI

@MainActor
struct HeatmapModuleBuilder {
    static func build(localStorageService: LocalStorageService, userPreferencesService: UserPreferencesService) -> some View {
        let viewModel = HeatmapViewModel(localStorageService: localStorageService, userPreferencesService: userPreferencesService)
        return HeatmapView(viewModel: viewModel)
    }
}
