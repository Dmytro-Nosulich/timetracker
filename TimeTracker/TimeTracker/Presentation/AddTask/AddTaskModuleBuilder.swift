import SwiftUI

@MainActor
struct AddTaskModuleBuilder {
    static func build(localStorageService: LocalStorageService) -> some View {
        let viewModel = AddTaskViewModel(localStorageService: localStorageService)
        return AddTaskView(viewModel: viewModel)
    }
}
