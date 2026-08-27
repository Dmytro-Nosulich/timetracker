import Foundation
import MCP

/// Registers the server's tools — all five in the spec's catalog.
enum MCPToolCatalog {

    static func register(
        on server: Server,
        dataStore: any MCPDataReading,
        preferences: any UserPreferencesService
    ) async {
        let listTasksAndTags = ListTasksAndTagsTool(dataStore: dataStore)
        let timeForTask = TimeForTaskTool(dataStore: dataStore)
        let timeForPeriod = TimeForPeriodTool(dataStore: dataStore)
        let reportBreakdown = ReportBreakdownTool(dataStore: dataStore, preferences: preferences)
        let saveReportPDF = SaveReportPDFTool(dataStore: dataStore, preferences: preferences)

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [
                ListTasksAndTagsTool.definition,
                TimeForTaskTool.definition,
                TimeForPeriodTool.definition,
                ReportBreakdownTool.definition,
                SaveReportPDFTool.definition,
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
            case ReportBreakdownTool.name:
                return await reportBreakdown.run(arguments: params.arguments)
            case SaveReportPDFTool.name:
                return await saveReportPDF.run(arguments: params.arguments)
            default:
                return MCPToolResponse.failure("Unknown tool: \(params.name)")
            }
        }
    }
}
