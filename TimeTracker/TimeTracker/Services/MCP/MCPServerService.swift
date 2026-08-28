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

    /// The block a user pastes into an MCP client's config file to reach this server.
    ///
    /// Uses the `mcpServers` wrapper, which Claude Desktop, Claude Code's `.mcp.json`,
    /// Cursor and Windsurf all read. (VS Code wants the same object under `servers`.)
    ///
    /// Deliberately a string template rather than `JSONEncoder`: the only variable in the
    /// whole document is an `Int` port reached through `url(port:)`, so there is no
    /// caller-supplied text to escape and nothing an encoder would protect against. An
    /// encoder would also render the URL as `http:\/\/…` unless someone remembers
    /// `.withoutEscapingSlashes` — valid JSON, but it reads as broken in a settings pane.
    /// `MCPServerConfigurationTests` parses this output, so a malformed edit fails a test
    /// rather than shipping something unpasteable.
    static func clientConfigurationJSON(port: Int = defaultPort) -> String {
        """
        {
          "mcpServers": {
            "\(serverName)": {
              "type": "http",
              "url": "\(url(port: port))"
            }
          }
        }
        """
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
