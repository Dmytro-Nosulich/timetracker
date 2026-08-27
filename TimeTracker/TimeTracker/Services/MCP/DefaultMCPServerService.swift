import Foundation
import MCP
import OSLog
import SwiftData
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix

/// Hosts the MCP server inside the running app, bound to loopback.
///
/// Main-actor isolated for its *state* only — observable status the menu bar and the
/// Settings screen read synchronously. The actual socket work happens on NIO's event loops
/// and the SDK's actors, so nothing here blocks the UI.
///
/// Preferences are the single source of truth for whether the server should be running and
/// on which port; nothing is cached across a bind. That's what lets `AppDelegate` call
/// `start()` unconditionally at launch and get auto-start-when-enabled for free.
@Observable
@MainActor
final class DefaultMCPServerService: MCPServerService {

    private(set) var status: MCPServerStatus = .stopped

    @ObservationIgnored private let coordinator: MCPSessionCoordinator
    @ObservationIgnored private let userPreferences: UserPreferencesService
    @ObservationIgnored private let logger = Logger(
        subsystem: "dmytro.TimeTracker",
        category: "MCPServer"
    )

    @ObservationIgnored private var channel: (any Channel)?

    convenience init(container: ModelContainer, userPreferences: UserPreferencesService) {
        self.init(
            dataStore: SwiftDataMCPDataStore(container: container),
            userPreferences: userPreferences
        )
    }

    /// Testing seam — lets a caller supply a data store without a `ModelContainer`.
    init(dataStore: any MCPDataReading, userPreferences: UserPreferencesService) {
        self.coordinator = MCPSessionCoordinator(dataStore: dataStore)
        self.userPreferences = userPreferences
    }

    // MARK: - Lifecycle

    func start() async {
        guard channel == nil else { return }
        guard userPreferences.mcpServerEnabled else {
            status = .stopped
            return
        }

        let port = userPreferences.mcpServerPort
        await coordinator.prepare()

        let coordinator = self.coordinator
        let endpointPath = MCPServerConfiguration.endpointPath
        let bootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.backlog, value: 64)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                    try channel.pipeline.syncOperations.addHandler(
                        MCPHTTPChannelHandler(coordinator: coordinator, endpointPath: endpointPath)
                    )
                }
            }

        do {
            // Binding the loopback address specifically — never 0.0.0.0 — is what keeps
            // this off the network. See MCPServerConfiguration.host.
            channel = try await bootstrap
                .bind(host: MCPServerConfiguration.host, port: port)
                .get()
            status = .running(port: port)
            logger.info("MCP server listening on \(MCPServerConfiguration.url(port: port), privacy: .public)")
        } catch {
            await coordinator.shutdown()
            fail(Self.bindFailureReason(error, port: port))
        }
    }

    /// Also clears a `.failed` status, so turning the server off after a bind failure
    /// reports "stopped" rather than leaving the old error on screen.
    func stop() async {
        let boundChannel = channel
        channel = nil

        try? await boundChannel?.close()
        await coordinator.shutdown()

        status = .stopped
        if boundChannel != nil {
            logger.info("MCP server stopped")
        }
    }

    /// Called by the Settings screen after it writes a preference, so a toggle or a port
    /// change takes effect without an app relaunch.
    func applyPreferences() async {
        guard userPreferences.mcpServerEnabled else {
            await stop()
            return
        }

        // Already exactly what preferences ask for. Note this deliberately does *not* match
        // on `.failed`: re-applying settings after a bind failure retries the bind, which is
        // what the Settings screen's Retry button relies on.
        if case .running(let boundPort) = status, boundPort == userPreferences.mcpServerPort {
            return
        }

        await stop()
        await start()
    }

    // MARK: - Failure reporting

    /// A bind failure is expected often enough (a stale copy of the app, another service
    /// on the port) that it must never take the app down — it lands in `status`, which
    /// the menu bar surfaces, and in the log.
    private func fail(_ reason: String) {
        status = .failed(reason: reason)
        logger.error("MCP server failed: \(reason, privacy: .public)")
    }

    private static func bindFailureReason(_ error: any Error, port: Int) -> String {
        if let ioError = error as? IOError, ioError.errnoCode == EADDRINUSE {
            return "port \(port) is already in use"
        }
        if let channelError = error as? NIOCore.ChannelError {
            return "could not bind port \(port) (\(channelError))"
        }
        return "could not bind port \(port) (\(error.localizedDescription))"
    }
}
