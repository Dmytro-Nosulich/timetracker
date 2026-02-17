import SwiftUI

struct TaskListView: View {
    let tasks: [TaskItem]
    let onDelete: (TaskItem) -> Void

    @State private var taskToDelete: TaskItem?

    var body: some View {
        List {
            if !tasks.isEmpty {
                HStack {
                    Text("")
                        .frame(width: 30)
                    Text("Task Title")
                        .fontWeight(.medium)
                    Spacer()
                    Text("Total Time")
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .trailing)
                    Text("")
                        .frame(width: 90)
                }
                .foregroundStyle(.secondary)
                .font(.caption)
                .listRowSeparator(.hidden)
            }

            ForEach(tasks) { task in
                TaskRowView(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        // Phase 4: open task detail window
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            taskToDelete = task
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text("Click the + button to add your first task.")
                )
            }
        }
        .confirmationDialog(
            "Delete Task",
            isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            ),
            presenting: taskToDelete
        ) { task in
            Button("Delete", role: .destructive) {
                onDelete(task)
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
        } message: { task in
            let hours = task.totalTrackedTime / 3600.0
            let formatted = String(format: "%.1f", hours)
            Text("Are you sure you want to delete '\(task.title)'? This task has \(formatted) hours of tracked time. This action cannot be undone.")
        }
    }
}
