import SwiftUI

struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(task.tags.prefix(3)) { tag in
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 30, alignment: .leading)

            Text(task.title)
                .lineLimit(1)

            Spacer()

            Text(task.totalTrackedTime.formattedHoursMinutes)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)

            Button {
                // Phase 3: start/pause timer
            } label: {
                Label("Start", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 90)
        }
        .padding(.vertical, 2)
    }
}
