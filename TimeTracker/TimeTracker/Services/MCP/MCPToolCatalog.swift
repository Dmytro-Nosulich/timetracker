import Foundation
import MCP

/// Registers the server's tools. Three so far; the report and PDF-export tools in the
/// spec's catalog land in later steps and plug in here.
enum MCPToolCatalog {

    static func register(on server: Server, dataStore: any MCPDataReading) async {
        let listTasksAndTags = ListTasksAndTagsTool(dataStore: dataStore)
        let timeForTask = TimeForTaskTool(dataStore: dataStore)
        let timeForPeriod = TimeForPeriodTool(dataStore: dataStore)

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [
                ListTasksAndTagsTool.definition,
                TimeForTaskTool.definition,
                TimeForPeriodTool.definition,
            ])
        }

        await server.withMethodHandler(CallTool.self) { params in
            switch params.name {
            case ListTasksAndTagsTool.name:
                return await listTasksAndTags.run(arguments: params.arguments)
            case TimeForTaskTool.name:
                return await timeForTask.run(arguments: params.arguments)
            case TimeForPeriodTool.name:
                return await timeForPeriod.run(arguments: params.arguments)
            default:
                return MCPToolResponse.failure("Unknown tool: \(params.name)")
            }
        }
    }
}
