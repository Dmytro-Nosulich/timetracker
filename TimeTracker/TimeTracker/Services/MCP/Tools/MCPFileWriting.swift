import Foundation

/// The slice of the filesystem `save_report_pdf` needs, behind a protocol so path
/// resolution can be tested without touching a real disk.
///
/// Same idea as `MCPDataReading`: a narrow, `Sendable` seam rather than handing the tool
/// a `FileManager` directly. It is deliberately tiny — the tool asks three questions and
/// performs one write, and nothing here creates directories.
protocol MCPFileWriting: Sendable {
    /// True only when the path exists *and* is a directory.
    func isDirectory(_ url: URL) -> Bool
    func fileExists(_ url: URL) -> Bool
    /// Writes atomically, replacing whatever is at `url`. Callers resolve collisions
    /// before getting here — see `ReportPDFDestination`.
    func write(_ data: Data, to url: URL) throws
}

struct DefaultMCPFileWriter: MCPFileWriting {
    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
