import SwiftUI

@MainActor
struct TimerWindowModuleBuilder {
    static func build(localStorageService: LocalStorageService, timerService: TimerService, userPreferences: UserPreferencesService) -> some View {
        let viewModel = TimerWindowViewModel(
            localStorageService: localStorageService,
            timerService: timerService,
            userPreferences: userPreferences
        )
        return TimerWindowView(viewModel: viewModel)
    }
}
