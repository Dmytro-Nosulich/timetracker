import SwiftUI

struct TimerWindowView: View {
    @State var viewModel: TimerWindowViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Session counter — large font
            Text(viewModel.sessionElapsed.formattedHoursMinutes)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()

            // Pause/Resume button
            Button {
                viewModel.togglePauseResume()
            } label: {
                if viewModel.state == .running {
                    Label("Pause", systemImage: "pause.fill")
                } else {
                    Label("Resume", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.state == .idle)

            // Task picker dropdown
            HStack {
                Text("Task:")
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { viewModel.currentTaskId ?? UUID() },
                    set: { viewModel.switchTask(to: $0) }
                )) {
                    ForEach(viewModel.tasks) { task in
                        Text(task.title).tag(task.id)
                    }
                }
                .labelsHidden()
            }
            .padding(.horizontal)

            // Today stats
            VStack(spacing: 4) {
                HStack {
                    Text("Today this task:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.todayThisTask.formattedHoursMinutes)
                        .monospacedDigit()
                }
                HStack {
                    Text("Today all tasks:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.todayAllTasks.formattedHoursMinutes)
                        .monospacedDigit()
                }
            }
            .font(.callout)
            .padding(.horizontal)

            // Inactivity banner (only when paused by inactivity)
            if viewModel.state == .pausedByInactivity {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Paused: inactivity")
                        .font(.caption)
                }
                .padding(8)
                .background(.orange.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 280)
        .onAppear {
            viewModel.loadTasks()
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .idle {
                dismiss()
            }
        }
    }
}
