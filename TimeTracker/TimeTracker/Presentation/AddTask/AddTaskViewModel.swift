import Foundation

@Observable
@MainActor
final class AddTaskViewModel {
    private let localStorageService: LocalStorageService

    var title: String = ""
    var taskDescription: String = ""
    var availableTags: [TagItem] = []
    var selectedTagIds: Set<UUID> = []

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(localStorageService: LocalStorageService) {
        self.localStorageService = localStorageService
        self.availableTags = localStorageService.fetchTags()
    }

    func toggleTag(id: UUID) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds.insert(id)
        }
    }

    func createTask() -> Bool {
        guard isValid else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        localStorageService.createTask(
            title: trimmedTitle,
            description: taskDescription,
            tagIds: Array(selectedTagIds)
        )
        return true
    }
}
