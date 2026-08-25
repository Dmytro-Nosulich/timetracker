import Foundation

struct SelectedDayTaskRow: Identifiable {
    let id: UUID
    let title: String
    let tags: [TagItem]
    let duration: TimeInterval
}
