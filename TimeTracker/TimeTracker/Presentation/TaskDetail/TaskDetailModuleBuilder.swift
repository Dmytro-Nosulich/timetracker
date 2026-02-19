import SwiftUI
import SwiftData

@MainActor
struct TaskDetailModuleBuilder {
    static func build(
        taskId: UUID,
        modelContainer: ModelContainer,
        coordinator: TaskDetailCoordinator,
        userPreferencesService: UserPreferencesService,
        onClose: @MainActor @escaping () -> Void
    ) -> some View {
        let viewModel = TaskDetailViewModel(
            taskId: taskId,
            modelContainer: modelContainer,
            coordinator: coordinator,
            currencySymbol: userPreferencesService.currencySymbol,
            onClose: onClose
        )
        return TaskDetailView(viewModel: viewModel)
    }
}
