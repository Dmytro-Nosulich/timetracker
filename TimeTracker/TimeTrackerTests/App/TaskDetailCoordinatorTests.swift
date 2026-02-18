import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct TaskDetailCoordinatorTests {

    @Test func requestOpenWithSameTaskCallsOpenWindow() {
        let coordinator = TaskDetailCoordinator()
        let taskId = UUID()
        coordinator.taskId = taskId

        var openWindowCallCount = 0
        coordinator.requestOpen(taskId: taskId) {
            openWindowCallCount += 1
        }

        #expect(openWindowCallCount == 1)
        #expect(coordinator.taskId == taskId)
        #expect(coordinator.showDiscardConfirmation == false)
    }

    @Test func requestOpenWithDifferentTaskAndNoChangesSwitches() {
        let coordinator = TaskDetailCoordinator()
        let taskA = UUID()
        let taskB = UUID()
        coordinator.taskId = taskA
        coordinator.hasUnsavedChanges = false

        var openWindowCallCount = 0
        coordinator.requestOpen(taskId: taskB) {
            openWindowCallCount += 1
        }

        #expect(openWindowCallCount == 1)
        #expect(coordinator.taskId == taskB)
        #expect(coordinator.showDiscardConfirmation == false)
    }

    @Test func requestOpenWithUnsavedChangesShowsConfirmation() {
        let coordinator = TaskDetailCoordinator()
        let taskA = UUID()
        let taskB = UUID()
        coordinator.taskId = taskA
        coordinator.hasUnsavedChanges = true

        var openWindowCallCount = 0
        coordinator.requestOpen(taskId: taskB) {
            openWindowCallCount += 1
        }

        #expect(openWindowCallCount == 0)
        #expect(coordinator.taskId == taskA)
        #expect(coordinator.showDiscardConfirmation == true)
    }

    @Test func confirmDiscardSwitchesTaskAndOpensWindow() {
        let coordinator = TaskDetailCoordinator()
        let taskA = UUID()
        let taskB = UUID()
        coordinator.taskId = taskA
        coordinator.hasUnsavedChanges = true

        var openWindowCallCount = 0
        coordinator.requestOpen(taskId: taskB) {
            openWindowCallCount += 1
        }

        coordinator.confirmDiscard()

        #expect(openWindowCallCount == 1)
        #expect(coordinator.taskId == taskB)
        #expect(coordinator.showDiscardConfirmation == false)
    }

    @Test func cancelDiscardKeepsCurrentTask() {
        let coordinator = TaskDetailCoordinator()
        let taskA = UUID()
        let taskB = UUID()
        coordinator.taskId = taskA
        coordinator.hasUnsavedChanges = true

        coordinator.requestOpen(taskId: taskB) {}

        coordinator.cancelDiscard()

        #expect(coordinator.taskId == taskA)
        #expect(coordinator.showDiscardConfirmation == false)
    }

    @Test func closeClearsAllState() {
        let coordinator = TaskDetailCoordinator()
        coordinator.taskId = UUID()
        coordinator.hasUnsavedChanges = true

        coordinator.close()

        #expect(coordinator.taskId == nil)
        #expect(coordinator.hasUnsavedChanges == false)
        #expect(coordinator.showDiscardConfirmation == false)
    }
}
