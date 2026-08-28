import Foundation
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1

/// Bridges NIO's HTTP/1.1 pipeline to the MCP SDK's framework-agnostic server transport.
///
/// The SDK's `StatelessHTTPServerTransport` turns an `MCP.HTTPRequest` into an
/// `MCP.HTTPResponse` but does not listen on a socket — this handler is the missing half.
/// Modeled on the SDK's own NIO adapter (`Sources/MCPConformance/Server/HTTPApp.swift`),
/// with two deliberate differences: responses always carry a `Content-Length`, and the
/// connection's keep-alive preference is honored. Without the former NIO close-delimits
/// the body, which stalls keep-alive clients.
final class MCPHTTPChannelHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private struct PendingRequest {
        let head: HTTPRequestHead
        var body: ByteBuffer
    }

    private let coordinator: MCPSessionCoordinator
    private let endpointPath: String
    private var pending: PendingRequest?

    init(coordinator: MCPSessionCoordinator, endpointPath: String) {
        self.coordinator = coordinator
        self.endpointPath = endpointPath
    }

    // MARK: - ChannelInboundHandler

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            pending = PendingRequest(head: head, body: context.channel.allocator.buffer(capacity: 0))

        case .body(var buffer):
            pending?.body.writeBuffer(&buffer)

        case .end:
            guard let request = pending else { return }
            pending = nil
            nonisolated(unsafe) let capturedContext = context
            Task { await self.respond(to: request, context: capturedContext) }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        context.close(promise: nil)
    }

    // MARK: - Request handling

    private func respond(to request: PendingRequest, context: ChannelHandlerContext) async {
        let path = String(request.head.uri.split(separator: "?").first ?? Substring(request.head.uri))

        guard path == endpointPath else {
            write(
                .error(statusCode: 404, .invalidRequest("Not Found")),
                requestHead: request.head,
                context: context
            )
            return
        }

        let response = await coordinator.handle(makeMCPRequest(from: request, path: path))
        write(response, requestHead: request.head, context: context)
    }

    private func makeMCPRequest(from request: PendingRequest, path: String) -> MCP.HTTPRequest {
        // Repeated header fields are joined per RFC 7230.
        var headers: [String: String] = [:]
        for (name, value) in request.head.headers {
            if let existing = headers[name] {
                headers[name] = existing + ", " + value
            } else {
                headers[name] = value
            }
        }

        let body: Data? = request.body.readableBytes > 0
            ? request.body.getBytes(at: 0, length: request.body.readableBytes).map { Data($0) }
            : nil

        return MCP.HTTPRequest(
            method: request.head.method.rawValue,
            headers: headers,
            body: body,
            path: path
        )
    }

    // MARK: - Response writing

    private func write(
        _ response: MCP.HTTPResponse,
        requestHead: HTTPRequestHead,
        context: ChannelHandlerContext
    ) {
        // The stateless transport never streams; treat it as a bug rather than hanging
        // the connection waiting for a body that will never be framed.
        if case .stream = response {
            write(
                .error(statusCode: 500, .internalError("Streaming responses are not supported")),
                requestHead: requestHead,
                context: context
            )
            return
        }

        nonisolated(unsafe) let capturedContext = context
        let keepAlive = requestHead.isKeepAlive
        let statusCode = response.statusCode
        let responseHeaders = response.headers
        let body = response.bodyData

        capturedContext.eventLoop.execute {
            var headers = HTTPHeaders()
            for (name, value) in responseHeaders {
                headers.add(name: name, value: value)
            }
            headers.replaceOrAdd(name: "Content-Length", value: String(body?.count ?? 0))
            headers.replaceOrAdd(name: "Connection", value: keepAlive ? "keep-alive" : "close")

            let head = HTTPResponseHead(
                version: requestHead.version,
                status: HTTPResponseStatus(statusCode: statusCode),
                headers: headers
            )
            capturedContext.write(self.wrapOutboundOut(.head(head)), promise: nil)

            if let body, !body.isEmpty {
                var buffer = capturedContext.channel.allocator.buffer(capacity: body.count)
                buffer.writeBytes(body)
                capturedContext.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }

            let end = capturedContext.eventLoop.makePromise(of: Void.self)
            if !keepAlive {
                end.futureResult.whenComplete { _ in capturedContext.close(promise: nil) }
            }
            capturedContext.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: end)
        }
    }
}
