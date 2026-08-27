import Foundation
import MCP

/// Registers the server's tools. One tool for now; the other four in the spec's catalog
/// land in later steps and plug in here.
enum MCPToolCatalog {

    static func register(on server: Server, dataStore: any MCPDataReading) async {
        let listTasksAndTags = ListTasksAndTagsTool(dataStore: dataStore)

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [ListTasksAndTagsTool.definition])
        }

        await server.withMethodHandler(CallTool.self) { params in
            switch params.name {
            case ListTasksAndTagsTool.name:
                return await listTasksAndTags.run(arguments: params.arguments)
            default:
                return CallTool.Result(
                    content: [
                        .text(
                            text: "Unknown tool: \(params.name)",
                            annotations: nil,
                            _meta: nil
                        )
                    ],
                    isError: true
                )
            }
        }
    }
}
