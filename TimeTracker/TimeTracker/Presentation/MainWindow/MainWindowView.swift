import SwiftUI

struct MainWindowView<AddTaskContent: View>: View {
    @State var viewModel: MainWindowViewModel
    @Bindable var coordinator: TaskDetailCoordinator
    @Environment(\.openWindow) private var openWindow
    let addTaskViewBuilder: () -> AddTaskContent

    var body: some View {
        VStack(spacing: 0) {
            TagFilterBar(tags: viewModel.tags, selectedTag: $viewModel.selectedTagFilter)

            Divider()

            TaskListView(
                tasks: viewModel.filteredTasks,
                currentTimerTaskId: viewModel.currentTimerTaskId,
                timerState: viewModel.timerState,
                onDelete: { task in viewModel.deleteTask(id: task.id) },
                onStartTimer: { task in
                    viewModel.startTimer(for: task)
                    openWindow(id: "timer-window")
                },
                onPauseTimer: {
                    viewModel.pauseTimer()
                },
                onOpenTaskDetail: { task in
                    coordinator.requestOpen(taskId: task.id) {
                        openWindow(id: "task-detail")
                    }
                }
            )

            Divider()

            BottomStatusBar(totalToday: viewModel.liveTotalToday)
        }
        .navigationTitle("Time Tracker")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Phase 7: open report window
                } label: {
                    Label("Report", systemImage: "chart.bar")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .sheet(isPresented: $viewModel.showingAddTask) {
            viewModel.loadData()
        } content: {
            addTaskViewBuilder()
        }
        .onAppear {
            viewModel.loadData()
        }
        .confirmationDialog("You have unsaved changes. Discard?", isPresented: $coordinator.showDiscardConfirmation) {
            Button("Discard", role: .destructive) {
                coordinator.confirmDiscard()
            }
            Button("Keep Editing", role: .cancel) {
                coordinator.cancelDiscard()
            }
        } message: {
            Text("Your changes will be lost if you switch to another task.")
        }
    }
}
