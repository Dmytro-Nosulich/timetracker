import SwiftUI
import SwiftData

struct TaskDetailWindowContent: View {
    let container: ModelContainer
    @Bindable var coordinator: TaskDetailCoordinator
    let userPreferencesService: UserPreferencesService
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let taskId = coordinator.taskId {
                TaskDetailModuleBuilder.build(
                    taskId: taskId,
                    modelContainer: container,
                    coordinator: coordinator,
                    userPreferencesService: userPreferencesService,
                    onClose: {
                        coordinator.close()
                        dismissWindow(id: "task-detail")
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
}
