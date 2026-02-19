import SwiftUI
import SwiftData

struct EditTimeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: EditTimeEntryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Time Entry")
                .font(.headline)

            if viewModel.entry.isManual {
                manualSection
            } else {
                trackedSection
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    if viewModel.save() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
        .alert("Time ranges overlap", isPresented: $viewModel.showOverlapWarning) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelOverlap()
            }
            Button("Save Anyway") {
                viewModel.confirmOverlapAndProceed()
                dismiss()
            }
        } message: {
            Text("This time range overlaps with existing entries. Continue anyway?")
        }
    }

    private var trackedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Start time", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
            DatePicker("End time", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hours")
                    .frame(width: 60, alignment: .leading)
                TextField("0", value: $viewModel.manualHours, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Minutes")
                    .frame(width: 60, alignment: .leading)
                TextField("0", value: $viewModel.manualMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Note (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Note", text: $viewModel.manualNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }
}
