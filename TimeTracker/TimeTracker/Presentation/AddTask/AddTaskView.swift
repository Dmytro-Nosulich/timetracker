import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: AddTaskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.headline)

            TextField("Task title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $viewModel.taskDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            if !viewModel.availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(viewModel.availableTags) { tag in
                            TagChip(
                                tag: tag,
                                isSelected: viewModel.selectedTagIds.contains(tag.id)
                            ) {
                                viewModel.toggleTag(id: tag.id)
                            }
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    if viewModel.createTask() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}
