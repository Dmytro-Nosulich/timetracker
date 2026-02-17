import SwiftUI

@MainActor
struct MainWindowModuleBuilder {
    static func build(localStorageService: LocalStorageService) -> some View {
        let viewModel = MainWindowViewModel(localStorageService: localStorageService)
        return MainWindowView(
            viewModel: viewModel,
            addTaskViewBuilder: {
                AddTaskModuleBuilder.build(localStorageService: localStorageService)
            }
        )
    }
}
