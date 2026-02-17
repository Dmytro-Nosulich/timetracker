import SwiftUI

struct MainWindowView<AddTaskContent: View>: View {
    @State var viewModel: MainWindowViewModel
    let addTaskViewBuilder: () -> AddTaskContent

    var body: some View {
        VStack(spacing: 0) {
            TagFilterBar(tags: viewModel.tags, selectedTag: $viewModel.selectedTagFilter)

            Divider()

            TaskListView(
                tasks: viewModel.filteredTasks,
                onDelete: { task in viewModel.deleteTask(id: task.id) }
            )

            Divider()

            BottomStatusBar(totalToday: viewModel.totalToday)
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
    }
}
