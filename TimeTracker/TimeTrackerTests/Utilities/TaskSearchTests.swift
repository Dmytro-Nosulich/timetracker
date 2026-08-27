import Testing
import Foundation
@testable import TimeTracker

struct TaskSearchTests {

    private func makeTask(title: String, description: String = "") -> TaskItem {
        TaskItem(
            id: UUID(),
            title: title,
            taskDescription: description,
            createdAt: Date(),
            isArchived: false,
            hourlyRate: nil,
            tags: [],
            timeEntries: [],
            totalTrackedTime: 0,
            trackedTimeToday: 0
        )
    }

    // MARK: - matches

    @Test func matchesOnTitle() {
        let task = makeTask(title: "Website redesign", description: "Nothing relevant")
        #expect(TaskSearch.matches(task, query: "website"))
    }

    @Test func matchesOnDescription() {
        let task = makeTask(title: "Unrelated", description: "Fix the login flow")
        #expect(TaskSearch.matches(task, query: "login"))
    }

    @Test func matchIsCaseInsensitive() {
        let task = makeTask(title: "Website redesign")
        #expect(TaskSearch.matches(task, query: "WEBSITE"))
        #expect(TaskSearch.matches(task, query: "wEbSiTe"))
    }

    @Test func matchIsSubstringNotPrefix() {
        let task = makeTask(title: "Website redesign")
        #expect(TaskSearch.matches(task, query: "redes"))
    }

    @Test func doesNotMatchUnrelatedQuery() {
        let task = makeTask(title: "Website redesign", description: "Landing page")
        #expect(TaskSearch.matches(task, query: "invoice") == false)
    }

    @Test func emptyQueryMatchesEverything() {
        let task = makeTask(title: "Website redesign")
        #expect(TaskSearch.matches(task, query: ""))
    }

    @Test func whitespaceOnlyQueryMatchesEverything() {
        let task = makeTask(title: "Website redesign")
        #expect(TaskSearch.matches(task, query: "   "))
    }

    @Test func queryIsTrimmedBeforeMatching() {
        let task = makeTask(title: "Website redesign")
        #expect(TaskSearch.matches(task, query: "  website  "))
    }

    // MARK: - filter

    @Test func filterReturnsOnlyMatchingTasks() {
        let tasks = [
            makeTask(title: "Website redesign"),
            makeTask(title: "Invoice chasing"),
            makeTask(title: "Unrelated", description: "website copy review")
        ]
        let result = TaskSearch.filter(tasks, query: "website")
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "Website redesign" })
        #expect(result.contains { $0.title == "Unrelated" })
    }

    @Test func filterWithEmptyQueryReturnsEverything() {
        let tasks = [makeTask(title: "One"), makeTask(title: "Two")]
        #expect(TaskSearch.filter(tasks, query: "").count == 2)
    }

    @Test func filterWithWhitespaceOnlyQueryReturnsEverything() {
        let tasks = [makeTask(title: "One"), makeTask(title: "Two")]
        #expect(TaskSearch.filter(tasks, query: "  \n ").count == 2)
    }

    @Test func filterWithNoMatchesReturnsEmpty() {
        let tasks = [makeTask(title: "One"), makeTask(title: "Two")]
        #expect(TaskSearch.filter(tasks, query: "nonexistent").isEmpty)
    }

    @Test func filterPreservesInputOrder() {
        let tasks = [
            makeTask(title: "Alpha project"),
            makeTask(title: "Beta project"),
            makeTask(title: "Gamma project")
        ]
        let result = TaskSearch.filter(tasks, query: "project")
        #expect(result.map(\.title) == ["Alpha project", "Beta project", "Gamma project"])
    }
}
