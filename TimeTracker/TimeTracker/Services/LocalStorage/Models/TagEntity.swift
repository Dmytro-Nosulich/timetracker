import Foundation
import SwiftData

@Model
final class TagEntity {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    var tasks: [TaskEntity]

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.tasks = []
    }
}
