import SwiftUI

@MainActor
struct MainWindowModuleBuilder {
    static func build(
        localStorageService: LocalStorageService,
        timerService: TimerService,
        coordinator: TaskDetailCoordinator
    ) -> some View {
        let viewModel = MainWindowViewModel(
            localStorageService: localStorageService,
            timerService: timerService
        )
        return MainWindowView(
            viewModel: viewModel,
            coordinator: coordinator,
            addTaskViewBuilder: {
                AddTaskModuleBuilder.build(localStorageService: localStorageService)
            }
        )
    }
}
