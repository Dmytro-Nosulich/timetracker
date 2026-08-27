import Foundation
import MCP
import OSLog

/// Owns the MCP `Server` and its transport, and rebuilds both whenever a client sends
/// `initialize`.
///
/// The rebuild is the whole point. `Server` accepts exactly one `initialize` for its
/// lifetime — a second one fails with "Server is already initialized" — so a single
/// long-lived server would be permanently poisoned by the first client that connected.
/// Since Claude Code re-initializes on every restart, and a stray `curl` probe would do
/// the same, the server has to be replaceable.
///
/// Dropping a session costs nothing here: the tools are read-only and hold no per-client
/// state, and the server runs non-strict, so tool calls work whether or not an
/// `initialize` preceded them. If a second client initializes while another is connected,
/// the first keeps working for the same reason.
actor MCPSessionCoordinator {

    private struct Session {
        let transport: StatelessHTTPServerTransport
        let server: Server
    }

    private let dataStore: any MCPDataReading
    private let logger = Logger(subsystem: "dmytro.TimeTracker", category: "MCPServer")
    private var session: Session?

    init(dataStore: any MCPDataReading) {
        self.dataStore = dataStore
    }

    // MARK: - Request handling

    func handle(_ request: MCP.HTTPRequest) async -> MCP.HTTPResponse {
        if session == nil || Self.isInitializeRequest(request) {
            await startNewSession()
        }

        guard let session else {
            return .error(statusCode: 500, .internalError("MCP server is unavailable"))
        }
        return await session.transport.handleRequest(request)
    }

    // MARK: - Session lifecycle

    /// Builds the first session up front so that a misconfigured tool catalog fails at
    /// launch rather than on the first client request.
    func prepare() async {
        guard session == nil else { return }
        await startNewSession()
    }

    func shutdown() async {
        await session?.server.stop()
        session = nil
    }

    private func startNewSession() async {
        await session?.server.stop()
        session = nil

        let transport = StatelessHTTPServerTransport()
        let server = Server(
            name: MCPServerConfiguration.serverName,
            version: MCPServerConfiguration.serverVersion,
            instructions: """
                Read-only access to the user's local TimeTracker app: the tasks and tags \
                they track time against, and the time they have tracked. The app must be \
                running for these tools to work.
                """,
            capabilities: .init(tools: .init(listChanged: false))
        )
        await MCPToolCatalog.register(on: server, dataStore: dataStore)

        do {
            try await server.start(transport: transport)
            session = Session(transport: transport, server: server)
        } catch {
            logger.error("Could not start an MCP session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The SDK classifies this internally but doesn't expose it, so read the method off
    /// the JSON-RPC body directly.
    private static func isInitializeRequest(_ request: MCP.HTTPRequest) -> Bool {
        guard let body = request.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return false }
        return json["method"] as? String == Initialize.name
    }
}
