import SwiftUI
import SwiftData
import AppKit

struct TaskDetailWindowContent: View {
    let container: ModelContainer
    @Bindable var coordinator: TaskDetailCoordinator
    let userPreferencesService: UserPreferencesService

    /// Holds a weak reference to the hosting NSWindow so we can close it via
    /// `NSWindow.close()` directly — SwiftUI's `dismissWindow` is unreliable for
    /// singleton `Window` scenes and silently fails when called from inside a
    /// `confirmationDialog` button action.
    @State private var windowProxy = WindowProxy()

    var body: some View {
        Group {
            if let taskId = coordinator.taskId {
                TaskDetailModuleBuilder.build(
                    taskId: taskId,
                    modelContainer: container,
                    coordinator: coordinator,
                    userPreferencesService: userPreferencesService,
                    onClose: { [windowProxy] in windowProxy.close() }
                )
                // WindowAccessor captures the NSWindow reference so onClose can
                // call window.close() directly, bypassing windowShouldClose.
                .background(WindowAccessor { [windowProxy] window in
                    windowProxy.window = window
                })
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Window helpers

/// Holds a weak reference to the hosting NSWindow and calls `close()` on it.
private final class WindowProxy {
    weak var window: NSWindow?
    @MainActor func close() { window?.close() }
}

/// Invisible NSViewRepresentable that captures the hosting NSWindow as soon as
/// the view is placed in the window hierarchy.
private struct WindowAccessor: NSViewRepresentable {
    let onWindowAvailable: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onWindowAvailable(window)
        } else {
            DispatchQueue.main.async { [weak nsView] in
                guard let window = nsView?.window else { return }
                self.onWindowAvailable(window)
            }
        }
    }
}
