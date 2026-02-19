//
//  TagPickerView.swift
//  TimeTracker
//
//  Created by Dmytro Nosulich on 19.02.26.
//

import SwiftUI

struct TagPickerView: View {
	let allTags: [TagEntity]
	let taskTags: [TagEntity]
	let onSelect: (TagEntity) -> Void
	let onCreate: (String, String) -> Void

	@State private var newTagName = ""
	@State private var newTagColor = "007AFF"

	private let presetColors = ["FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "007AFF", "5856D6", "AF52DE"]

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Add Tag")
				.font(.headline)

			if !allTags.isEmpty {
				let availableTags = allTags.filter { t in !taskTags.contains(where: { $0.id == t.id }) }
				if availableTags.isEmpty {
					Text("All tags are already added.")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					List(availableTags, id: \.id) { tag in
						Button {
							onSelect(tag)
						} label: {
							HStack {
								Circle()
									.fill(Color(hex: tag.colorHex))
									.frame(width: 10, height: 10)
								Text(tag.name)
							}
						}
					}
				}
			}

			Divider()

			Text("Create new tag")
				.font(.subheadline)

			TextField("Tag name", text: $newTagName)
				.textFieldStyle(.roundedBorder)

			HStack {
				ForEach(presetColors, id: \.self) { hex in
					Button {
						newTagColor = hex
					} label: {
						Circle()
							.fill(Color(hex: hex))
							.frame(width: 24, height: 24)
							.overlay(
								Circle()
									.stroke(newTagColor == hex ? Color.primary : Color.clear, lineWidth: 2)
							)
					}
					.buttonStyle(.plain)
				}
			}

			Button("Create & Add") {
				onCreate(newTagName, newTagColor)
			}
			.disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
		}
		.padding()
	}
}


#Preview {
	TagPickerView(allTags: [TagEntity(name: "Tag1", colorHex: "FF3B30")],
				  taskTags: [TagEntity(name: "Tag2", colorHex: "FF9500")],
				  onSelect: { _ in },
				  onCreate: { _, _ in })
}
