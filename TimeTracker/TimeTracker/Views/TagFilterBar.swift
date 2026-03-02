import SwiftUI

struct TagFilterBar: View {
    let tags: [TagItem]
    @Binding var selectedTag: TagItem?

    var body: some View {
        HStack {
            Text("Filter:")
                .foregroundStyle(.secondary)
            Picker("Tag", selection: $selectedTag) {
                Text("All Tags").tag(nil as TagItem?)
                ForEach(tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color(hex: tag.colorHex))
                            .font(.system(size: 8))
                    }
                    .tag(tag as TagItem?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
