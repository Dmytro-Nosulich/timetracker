import Foundation

/// Lets `AppDelegate` reach the MCP server, which is constructed in `TimeTrackerApp.init()`
/// alongside the `ModelContainer` it reads from. Same pattern as `TimerServiceHolder`.
@MainActor
final class MCPServerServiceHolder {
    static var shared: MCPServerService?
}
