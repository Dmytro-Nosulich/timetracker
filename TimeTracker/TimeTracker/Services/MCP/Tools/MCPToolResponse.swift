import Foundation
import MCP

/// How every tool turns a payload into an MCP result, so the tools can't drift apart on
/// JSON formatting or on what an error looks like.
enum MCPToolResponse {

    /// Pretty-printed and key-sorted: these payloads are read by a model and, when
    /// something goes wrong, by a human reading a transcript.
    static func json(_ payload: some Encodable, fallbackMessage: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else {
            return #"{"error":"\#(fallbackMessage)"}"#
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func success(_ text: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            isError: false
        )
    }

    /// A caller error — a malformed argument. Reserved for calls that can't be answered
    /// at all; "nothing matched" is a valid answer and must not come back this way.
    static func failure(_ message: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
