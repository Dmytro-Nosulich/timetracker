import Foundation

/// Fixed settings for the embedded MCP server. The port and the enabled flag live in
/// `UserPreferencesService`; this is the default they start from.
enum MCPServerConfiguration {
    /// Loopback only — never `0.0.0.0`. The server exposes local time-tracking data and
    /// must not be reachable from the network.
    static let host = "127.0.0.1"
    static let defaultPort = 8427
    static let endpointPath = "/mcp"

    /// 1024 and up — privileged ports are rejected in Settings rather than failing at bind
    /// time with a permission error the user can do nothing about.
    static let validPortRange = 1024...65535

    static let serverName = "timetracker"
    static let serverVersion = "1.0.0"

    static func url(port: Int = defaultPort) -> String {
        "http://\(host):\(port)\(endpointPath)"
    }
}

enum MCPServerStatus: Equatable {
    case stopped
    case running(port: Int)
    /// The server could not bind (port already in use, sandbox denial, …). The app keeps
    /// running; the reason is surfaced in the menu bar and the log.
    case failed(reason: String)
}

@MainActor
protocol MCPServerService: AnyObject {
    var status: MCPServerStatus { get }
    /// Starts on the configured port, or does nothing if the server is disabled in
    /// preferences. Never throws — a failure to bind lands in `status` instead, so a busy
    /// port can't take the app down with it.
    func start() async
    func stop() async
    /// Re-reads preferences and brings the listener in line with them: starts, stops or
    /// rebinds. Idempotent — a no-op when already running on the configured port.
    func applyPreferences() async
}
