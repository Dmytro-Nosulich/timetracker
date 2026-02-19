import SwiftUI

struct TagColorPalette: View {
    @Binding var selectedHex: String

    static let colors: [(name: String, hex: String)] = [
        ("Red", "FF3B30"),
        ("Blue", "007AFF"),
        ("Green", "34C759"),
        ("Yellow", "FFCC00"),
        ("Orange", "FF9500"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Gray", "8E8E93"),
        ("Teal", "5AC8FA"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.colors, id: \.hex) { color in
                Circle()
                    .fill(Color(hex: color.hex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: selectedHex == color.hex ? 2 : 0)
                    )
                    .onTapGesture {
                        selectedHex = color.hex
                    }
                    .accessibilityLabel(color.name)
            }
        }
    }
}
