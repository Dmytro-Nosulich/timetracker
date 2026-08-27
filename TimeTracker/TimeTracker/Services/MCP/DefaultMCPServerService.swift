import Foundation
import MCP
import OSLog
import SwiftData
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix

/// Hosts the MCP server inside the running app, bound to loopback.
///
/// Main-actor isolated for its *state* only — observable status the menu bar and (from
/// Step 3) the Settings screen read synchronously. The actual socket work happens on
/// NIO's event loops and the SDK's actors, so nothing here blocks the UI.
@Observable
@MainActor
final class DefaultMCPServerService: MCPServerService {

    private(set) var status: MCPServerStatus = .stopped

    @ObservationIgnored private let coordinator: MCPSessionCoordinator
    @ObservationIgnored private let port: Int
    @ObservationIgnored private let logger = Logger(
        subsystem: "dmytro.TimeTracker",
        category: "MCPServer"
    )

    @ObservationIgnored private var channel: (any Channel)?

    convenience init(container: ModelContainer, port: Int = MCPServerConfiguration.defaultPort) {
        self.init(dataStore: SwiftDataMCPDataStore(container: container), port: port)
    }

    /// Testing seam — lets a caller supply a data store without a `ModelContainer`.
    init(dataStore: any MCPDataReading, port: Int = MCPServerConfiguration.defaultPort) {
        self.coordinator = MCPSessionCoordinator(dataStore: dataStore)
        self.port = port
    }

    // MARK: - Lifecycle

    func start() async {
        guard channel == nil else { return }

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
            logger.info("MCP server listening on \(MCPServerConfiguration.url(port: self.port), privacy: .public)")
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
