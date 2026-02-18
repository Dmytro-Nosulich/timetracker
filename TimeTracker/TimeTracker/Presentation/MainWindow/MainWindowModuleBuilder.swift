import SwiftUI

@MainActor
struct MainWindowModuleBuilder {
    static func build(localStorageService: LocalStorageService, timerService: TimerService) -> some View {
        let viewModel = MainWindowViewModel(
            localStorageService: localStorageService,
            timerService: timerService
        )
        return MainWindowView(
            viewModel: viewModel,
            addTaskViewBuilder: {
                AddTaskModuleBuilder.build(localStorageService: localStorageService)
            }
        )
    }
}
