//
//  TimeEntryRowView.swift
//  TimeTracker
//
//  Created by Dmytro Nosulich on 19.02.26.
//

import SwiftUI

struct TimeEntryRowView: View {
	let entry: TimeEntryEntity
	let onEdit: () -> Void
	let onDelete: () -> Void

	private static let timeFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm"
		return f
	}()

	var body: some View {
		HStack {
			if entry.isManual {
				VStack(alignment: .leading, spacing: 2) {
					Text("Manual entry \(entry.duration.formattedHoursMinutes)")
					if let note = entry.note, !note.isEmpty {
						Text(note)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			} else {
				Text(timeRangeString)
			}

			Spacer()

			Button {
				onEdit()
			} label: {
				Image(systemName: "pencil")
			}
			.buttonStyle(.borderless)

			Button(role: .destructive) {
				onDelete()
			} label: {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
		}
		.padding(.vertical, 4)
	}

	private var timeRangeString: String {
		let start = Self.timeFormatter.string(from: entry.startDate)
		let end = entry.endDate.map { Self.timeFormatter.string(from: $0) } ?? "—"
		return "\(start) – \(end) (\(entry.duration.formattedHoursMinutes))"
	}
}


#Preview {
	TimeEntryRowView(entry: TimeEntryEntity(task: TaskEntity(title: "Some Task"),
											startDate: Date()),
					 onEdit: {},
					 onDelete: {})
}
