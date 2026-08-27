import Testing
import Foundation
@testable import TimeTracker

struct MCPServerConfigurationTests {

    // MARK: - Client configuration JSON

    /// The block is a string template, so this is what stands between an edit and shipping
    /// something a user cannot paste. Parse it rather than comparing text.
    @Test func clientConfigurationJSONIsValidJSON() throws {
        let data = try #require(MCPServerConfiguration.clientConfigurationJSON().data(using: .utf8))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let servers = try #require(root?["mcpServers"] as? [String: Any])
        let entry = try #require(servers[MCPServerConfiguration.serverName] as? [String: Any])

        #expect(entry["type"] as? String == "http")
        #expect(entry["url"] as? String == MCPServerConfiguration.url())
        #expect(servers.count == 1)
    }

    @Test func clientConfigurationJSONCarriesTheGivenPort() throws {
        let json = MCPServerConfiguration.clientConfigurationJSON(port: 9000)
        let data = try #require(json.data(using: .utf8))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let servers = try #require(root?["mcpServers"] as? [String: Any])
        let entry = try #require(servers[MCPServerConfiguration.serverName] as? [String: Any])

        #expect(entry["url"] as? String == "http://127.0.0.1:9000/mcp")
    }

    /// The Settings pane shows the URL and this JSON side by side. If they ever disagreed,
    /// one of the two copy buttons would be handing out an address nothing is listening on.
    @Test func clientConfigurationJSONAndURLCannotDisagree() throws {
        for port in [MCPServerConfiguration.defaultPort, 1024, 65535, 12345] {
            let data = try #require(
                MCPServerConfiguration.clientConfigurationJSON(port: port).data(using: .utf8)
            )
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let servers = try #require(root?["mcpServers"] as? [String: Any])
            let entry = try #require(servers[MCPServerConfiguration.serverName] as? [String: Any])

            #expect(entry["url"] as? String == MCPServerConfiguration.url(port: port))
        }
    }

    /// `JSONEncoder` would emit `http:\/\/…` by default. That parses, but it reads as broken
    /// to someone looking at it in Settings, which is the whole reason this is a template.
    @Test func clientConfigurationJSONDoesNotEscapeSlashes() {
        let json = MCPServerConfiguration.clientConfigurationJSON()

        #expect(!json.contains("\\/"))
        #expect(json.contains("http://127.0.0.1:\(MCPServerConfiguration.defaultPort)/mcp"))
    }

    // MARK: - URL

    @Test func urlIsLoopbackOnly() {
        #expect(MCPServerConfiguration.host == "127.0.0.1")
        #expect(MCPServerConfiguration.url(port: 8427) == "http://127.0.0.1:8427/mcp")
    }
}
