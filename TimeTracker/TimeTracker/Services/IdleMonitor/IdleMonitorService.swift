import Foundation

/// Observes timer state and system idle/sleep to auto-pause the timer and show Welcome back when the user returns.
@MainActor
protocol IdleMonitorService: AnyObject {
    /// Starts observing timer state and system notifications. Call once at app launch.
    func start()
}
