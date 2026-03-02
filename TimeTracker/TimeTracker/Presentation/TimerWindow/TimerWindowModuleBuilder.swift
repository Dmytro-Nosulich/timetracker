import SwiftUI

@MainActor
struct TimerWindowModuleBuilder {
    static func build(localStorageService: LocalStorageService, timerService: TimerService) -> some View {
        let viewModel = TimerWindowViewModel(
            localStorageService: localStorageService,
            timerService: timerService
        )
        return TimerWindowView(viewModel: viewModel)
    }
}
