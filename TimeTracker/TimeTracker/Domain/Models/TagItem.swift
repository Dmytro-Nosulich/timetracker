import Foundation

struct TagItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String
    let createdAt: Date
}
