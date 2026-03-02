import SwiftUI
import AppKit

/// An invisible `NSViewRepresentable` placed in `TaskDetailView` that installs an
/// `NSWindowDelegate` on the hosting window.  This lets us:
///  - intercept the system red-button close (`windowShouldClose`) and show the
///    unsaved-changes confirmation before the window closes, and
///  - call clean-up code (`windowWillClose`) regardless of *how* the window closes.
struct WindowCloseInterceptor: NSViewRepresentable {
    /// Return `true` to prevent the window from closing (e.g. show a confirmation).
    var onWindowShouldClose: @MainActor () -> Bool
    /// Called just before the window closes, no matter how it was triggered.
    var onWindowWillClose: @MainActor () -> Void

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Keep the closures up-to-date every time the parent view re-renders.
        context.coordinator.onWindowShouldClose = onWindowShouldClose
        context.coordinator.onWindowWillClose = onWindowWillClose

        if let window = nsView.window {
            installDelegate(context.coordinator, on: window)
        } else {
            // The view may not be in a window yet on the first pass; retry next
            // run-loop tick once layout has finished.
            DispatchQueue.main.async { [weak nsView] in
                guard let window = nsView?.window else { return }
                self.installDelegate(context.coordinator, on: window)
            }
        }
    }

    func makeCoordinator() -> WindowDelegate {
        WindowDelegate(
            onWindowShouldClose: onWindowShouldClose,
            onWindowWillClose: onWindowWillClose
        )
    }

    // MARK: - Private helpers

    private func installDelegate(_ delegate: WindowDelegate, on window: NSWindow) {
        guard window.delegate !== delegate else { return }
        delegate.previousDelegate = window.delegate
        window.delegate = delegate
    }

    // MARK: - NSWindowDelegate

    @MainActor
    final class WindowDelegate: NSObject, NSWindowDelegate {
        var onWindowShouldClose: @MainActor () -> Bool
        var onWindowWillClose: @MainActor () -> Void
        /// Any pre-existing delegate that was on the window (chain-forwarded).
        weak var previousDelegate: (any NSWindowDelegate)?

        init(
            onWindowShouldClose: @MainActor @escaping () -> Bool,
            onWindowWillClose: @MainActor @escaping () -> Void
        ) {
            self.onWindowShouldClose = onWindowShouldClose
            self.onWindowWillClose = onWindowWillClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if onWindowShouldClose() {
                return false   // prevent close; caller is responsible for showing UI
            }
            return previousDelegate?.windowShouldClose?(sender) ?? true
        }

        func windowWillClose(_ notification: Notification) {
            onWindowWillClose()
            previousDelegate?.windowWillClose?(notification)
        }
    }
}
