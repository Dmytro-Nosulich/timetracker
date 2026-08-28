import Foundation
@testable import TimeTracker

/// Stands in for the filesystem so `ReportPDFDestination`'s rules can be tested without
/// creating real folders. Conventions follow `MockMCPDataStore`: `stubbed<X>` inputs,
/// `<method>CallCount` / `<method>Last<Param>` recording.
final class MockMCPFileWriter: MCPFileWriting, @unchecked Sendable {
    /// Paths that should answer `isDirectory` with true.
    var stubbedDirectories: Set<String> = []
    /// Paths that should answer `fileExists` with true. Directories are treated as
    /// existing automatically, so tests only list the files they care about.
    var stubbedFiles: Set<String> = []
    /// When set, `write` throws it instead of recording.
    var stubbedWriteError: Error?

    private(set) var writeCallCount = 0
    private(set) var writeLastData: Data?
    private(set) var writeLastURL: URL?

    func isDirectory(_ url: URL) -> Bool {
        stubbedDirectories.contains(url.path)
    }

    func fileExists(_ url: URL) -> Bool {
        stubbedFiles.contains(url.path) || stubbedDirectories.contains(url.path)
    }

    func write(_ data: Data, to url: URL) throws {
        writeCallCount += 1
        writeLastData = data
        writeLastURL = url
        if let stubbedWriteError { throw stubbedWriteError }
    }
}
