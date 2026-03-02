import Foundation
import SwiftUI

@Observable
@MainActor
final class TaskDetailCoordinator {
    var taskId: UUID?
    var hasUnsavedChanges: Bool = false

    /// Set when user needs to confirm discard. When true, show confirmation dialog.
    var showDiscardConfirmation: Bool = false

    /// Pending task ID to open after user confirms discard.
    private var pendingOpenTaskId: UUID?
    private var pendingOpenAction: (() -> Void)?

    /// Request to open the Task Detail window for the given task.
    /// - Parameters:
    ///   - taskId: The task to show
    ///   - openWindow: Closure to open/focus the Task Detail window
    func requestOpen(taskId: UUID, openWindow: @escaping () -> Void) {
        if self.taskId == taskId {
            openWindow()
            return
        }

        if hasUnsavedChanges {
            pendingOpenTaskId = taskId
            pendingOpenAction = openWindow
            showDiscardConfirmation = true
            return
        }

        self.taskId = taskId
        openWindow()
    }

    /// Called when user confirms "Discard" in the unsaved changes dialog.
    func confirmDiscard() {
        showDiscardConfirmation = false
        hasUnsavedChanges = false
        if let id = pendingOpenTaskId, let action = pendingOpenAction {
            pendingOpenTaskId = nil
            pendingOpenAction = nil
            taskId = id
            action()
        }
    }

    /// Called when user chooses "Keep Editing".
    func cancelDiscard() {
        showDiscardConfirmation = false
        pendingOpenTaskId = nil
        pendingOpenAction = nil
    }

    /// Close the Task Detail window and clear state.
    func close() {
        taskId = nil
        hasUnsavedChanges = false
        pendingOpenTaskId = nil
        pendingOpenAction = nil
        showDiscardConfirmation = false
    }
}
