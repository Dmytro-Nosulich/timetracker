import SwiftUI

struct AddTimeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddTimeEntryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Time Entry")
                .font(.headline)

            Picker("Mode", selection: $viewModel.mode) {
                Text("Add tracked time").tag(AddTimeEntryViewModel.Mode.tracked)
                Text("Add duration").tag(AddTimeEntryViewModel.Mode.manual)
            }
            .pickerStyle(.segmented)

            switch viewModel.mode {
            case .tracked:
                trackedSection
            case .manual:
                manualSection
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if viewModel.submit() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 320)
        .alert("Time ranges overlap", isPresented: $viewModel.showOverlapWarning) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelOverlap()
            }
            Button("Add Anyway") {
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
