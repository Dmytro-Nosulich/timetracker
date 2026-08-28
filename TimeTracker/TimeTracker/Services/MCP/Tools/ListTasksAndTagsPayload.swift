import Foundation

/// Which tasks the `list_tasks_and_tags` tool should return.
enum ListTasksFilter: String, CaseIterable {
    case active
    case archived
    case all

    static let fallback = ListTasksFilter.active

    /// Anything unrecognised (including a missing argument) falls back to `active`, so a
    /// malformed call still returns something useful instead of an error.
    init(argument: String?) {
        guard let argument,
              let parsed = ListTasksFilter(rawValue: argument.lowercased())
        else {
            self = .fallback
            return
        }
        self = parsed
    }

    func includes(_ task: TaskItem) -> Bool {
        switch self {
        case .active: !task.isArchived
        case .archived: task.isArchived
        case .all: true
        }
    }
}

/// The JSON body returned by `list_tasks_and_tags`.
struct ListTasksAndTagsPayload: Encodable, Equatable {

    struct TaskSummary: Encodable, Equatable {
        let id: String
        let title: String
        let description: String
        let isArchived: Bool
        let tags: [String]
        let totalTrackedTimeSeconds: Int
        let totalTrackedTimeFormatted: String
    }

    struct TagSummary: Encodable, Equatable {
        let id: String
        let name: String
        let colorHex: String
    }

    /// Which filter produced `tasks`, echoed back so the caller can tell whether it got
    /// the default rather than what it asked for.
    let filter: String
    let taskCount: Int
    let tagCount: Int
    let tasks: [TaskSummary]
    let tags: [TagSummary]
}

/// Turns domain models into the tool's JSON payload. Pure — no storage, no MCP.
enum ListTasksAndTagsPayloadBuilder {

    static func build(
        tasks: [TaskItem],
        tags: [TagItem],
        filter: ListTasksFilter
    ) -> ListTasksAndTagsPayload {
        let matching = tasks.filter { filter.includes($0) }

        return ListTasksAndTagsPayload(
            filter: filter.rawValue,
            taskCount: matching.count,
            tagCount: tags.count,
            tasks: matching.map { task in
                ListTasksAndTagsPayload.TaskSummary(
                    id: task.id.uuidString,
                    title: task.title,
                    description: task.taskDescription,
                    isArchived: task.isArchived,
                    tags: task.tags.map(\.name),
                    // A still-running entry counts up to now, so this can move between
                    // two calls — that's the same number the app's UI shows.
                    totalTrackedTimeSeconds: Int(task.totalTrackedTime),
                    totalTrackedTimeFormatted: task.totalTrackedTime.formattedHoursMinutes
                )
            },
            tags: tags.map { tag in
                ListTasksAndTagsPayload.TagSummary(
                    id: tag.id.uuidString,
                    name: tag.name,
                    colorHex: tag.colorHex
                )
            }
        )
    }
}
