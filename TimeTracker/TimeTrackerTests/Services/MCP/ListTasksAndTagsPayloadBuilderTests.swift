import Testing
import Foundation
@testable import TimeTracker

struct ListTasksAndTagsPayloadBuilderTests {

    // MARK: - Fixtures

    private func makeTag(name: String = "Client", colorHex: String = "#FF0000") -> TagItem {
        TagItem(id: UUID(), name: name, colorHex: colorHex, createdAt: Date())
    }

    private func makeTask(
        id: UUID = UUID(),
        title: String = "Task",
        description: String = "",
        isArchived: Bool = false,
        tags: [TagItem] = [],
        totalTrackedTime: TimeInterval = 0
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            taskDescription: description,
            createdAt: Date(),
            isArchived: isArchived,
            hourlyRate: nil,
            tags: tags,
            timeEntries: [],
            totalTrackedTime: totalTrackedTime,
            trackedTimeToday: 0
        )
    }

    // MARK: - Filtering

    @Test func activeFilterOmitsArchivedTasks() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [
                makeTask(title: "Live", isArchived: false),
                makeTask(title: "Old", isArchived: true),
            ],
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.map(\.title) == ["Live"])
        #expect(payload.taskCount == 1)
        #expect(payload.filter == "active")
    }

    @Test func archivedFilterReturnsOnlyArchivedTasks() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [
                makeTask(title: "Live", isArchived: false),
                makeTask(title: "Old", isArchived: true),
            ],
            tags: [],
            filter: .archived
        )

        #expect(payload.tasks.map(\.title) == ["Old"])
        #expect(payload.tasks.map(\.isArchived) == [true])
    }

    @Test func allFilterReturnsBoth() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [
                makeTask(title: "Live", isArchived: false),
                makeTask(title: "Old", isArchived: true),
            ],
            tags: [],
            filter: .all
        )

        #expect(payload.tasks.map(\.title) == ["Live", "Old"])
        #expect(payload.taskCount == 2)
    }

    @Test func emptyStoreProducesEmptyListsRatherThanAnError() {
        let payload = ListTasksAndTagsPayloadBuilder.build(tasks: [], tags: [], filter: .all)

        #expect(payload.tasks.isEmpty)
        #expect(payload.tags.isEmpty)
        #expect(payload.taskCount == 0)
        #expect(payload.tagCount == 0)
    }

    // MARK: - Task contents

    @Test func taskCarriesItsIdSoAFollowUpCallCanTargetIt() {
        let id = UUID()
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(id: id, title: "Invoicing")],
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.first?.id == id.uuidString)
    }

    @Test func taskCarriesDescriptionSinceTheSearchToolMatchesOnIt() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(title: "Invoicing", description: "Monthly billing run")],
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.first?.description == "Monthly billing run")
    }

    @Test func taskCarriesTagNames() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(tags: [makeTag(name: "Acme"), makeTag(name: "Billable")])],
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.first?.tags == ["Acme", "Billable"])
    }

    @Test func taskTotalIsReportedInSecondsAndFormatted() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(totalTrackedTime: 4530)],  // 1h 15m 30s
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.first?.totalTrackedTimeSeconds == 4530)
        #expect(payload.tasks.first?.totalTrackedTimeFormatted == TimeInterval(4530).formattedHoursMinutes)
        #expect(payload.tasks.first?.totalTrackedTimeFormatted == "1h 15m")
    }

    @Test func taskOrderIsPreservedFromStorage() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(title: "Newest"), makeTask(title: "Middle"), makeTask(title: "Oldest")],
            tags: [],
            filter: .active
        )

        #expect(payload.tasks.map(\.title) == ["Newest", "Middle", "Oldest"])
    }

    // MARK: - Tags

    @Test func tagsAreListedRegardlessOfTheTaskFilter() {
        let payload = ListTasksAndTagsPayloadBuilder.build(
            tasks: [makeTask(isArchived: true)],
            tags: [makeTag(name: "Acme", colorHex: "#123456")],
            filter: .active
        )

        #expect(payload.tasks.isEmpty)
        #expect(payload.tagCount == 1)
        #expect(payload.tags.first?.name == "Acme")
        #expect(payload.tags.first?.colorHex == "#123456")
    }

    // MARK: - Filter parsing

    @Test func missingArgumentFallsBackToActive() {
        #expect(ListTasksFilter(argument: nil) == .active)
    }

    @Test func unrecognisedArgumentFallsBackToActive() {
        #expect(ListTasksFilter(argument: "everything") == .active)
    }

    @Test func argumentParsingIsCaseInsensitive() {
        #expect(ListTasksFilter(argument: "Archived") == .archived)
        #expect(ListTasksFilter(argument: "ALL") == .all)
    }
}
