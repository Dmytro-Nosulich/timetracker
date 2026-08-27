import Foundation

/// Works out exactly which file `save_report_pdf` should write, from a destination path
/// the caller supplied in whatever shape came naturally — "~/Desktop", or
/// "/Users/me/Reports/July.pdf".
///
/// Pure apart from the three questions it asks `MCPFileWriting`, so the rules below are
/// unit-testable without a real disk. It never creates directories: a caller that names a
/// folder which doesn't exist has almost certainly made a typo, and silently creating it
/// would leave next month's report somewhere nobody looks.
enum ReportPDFDestination {

    /// How many " (N)" suffixes to try before giving up. Well past the point where a
    /// caller is looping by accident.
    static let maximumCollisionAttempts = 99

    // MARK: - Result

    struct Resolved: Equatable {
        /// Where the bytes actually go, collisions already resolved.
        let url: URL
        /// What the file would have been called had nothing been in the way. Differs from
        /// `filename` only when a collision forced a rename.
        let requestedFilename: String

        var filename: String { url.lastPathComponent }
        var directory: String { url.deletingLastPathComponent().path }
        var renamedToAvoidOverwrite: Bool { filename != requestedFilename }
    }

    // MARK: - Failures

    /// Every case names the fix, following `MCPPeriodArgument.Failure` — these messages
    /// are what the AI reads when deciding how to retry the call.
    enum Failure: Error, Equatable {
        case missingPath
        case relativePath(String)
        case missingDirectory(String)
        case missingParentDirectory(path: String, parent: String)
        case notADirectory(String)
        case emptyFilename
        case filenameWithSeparator(String)
        case filenameAlongsideFilePath(String)
        case tooManyCollisions(String)

        var message: String {
            switch self {
            case .missingPath:
                "Missing \"destination_path\". Pass the folder to save into, e.g. \"~/Desktop\", "
                    + "or a full path ending in .pdf."
            case .relativePath(let path):
                "\"\(path)\" is a relative path. Pass an absolute path or one starting with \"~\"."
            case .missingDirectory(let path):
                "The folder \"\(path)\" does not exist. Pass a folder that already exists, "
                    + "or a full path ending in .pdf inside one that does."
            case .missingParentDirectory(let path, let parent):
                "Cannot save to \"\(path)\" because the folder \"\(parent)\" does not exist. "
                    + "Create it first, or choose a folder that already exists."
            case .notADirectory(let path):
                "\"\(path)\" is a file, not a folder, and does not end in .pdf. Pass a folder "
                    + "to save into, or a full path ending in .pdf."
            case .emptyFilename:
                "\"filename\" is empty. Leave it out to use the default report name, or pass a name."
            case .filenameWithSeparator(let filename):
                "\"filename\" must be a file name, not a path — \"\(filename)\" contains \"/\". "
                    + "Put the folder in destination_path instead."
            case .filenameAlongsideFilePath(let path):
                "destination_path \"\(path)\" already names the file to write, so \"filename\" "
                    + "would be ignored. Pass a folder as destination_path, or drop \"filename\"."
            case .tooManyCollisions(let filename):
                "Gave up finding a free name near \"\(filename)\" after "
                    + "\(maximumCollisionAttempts) attempts. Clear out the folder or pass a filename."
            }
        }
    }

    // MARK: - Resolution

    /// - Parameter defaultFilename: used when the caller gave a folder and no `filename`.
    ///   Comes from `ReportPeriod.defaultFilename(startDate:endDate:)`, so a headless call
    ///   names the file exactly as the Report screen's save panel would have suggested.
    static func resolve(
        path rawPath: String?,
        filename rawFilename: String?,
        defaultFilename: String,
        fileWriter: any MCPFileWriting
    ) -> Result<Resolved, Failure> {
        guard let trimmedPath = nonEmpty(rawPath) else { return .failure(.missingPath) }

        let expanded = (trimmedPath as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return .failure(.relativePath(trimmedPath)) }

        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let requestedName: String
        let target: URL

        if fileWriter.isDirectory(url) {
            switch filename(from: rawFilename, default: defaultFilename) {
            case .failure(let failure):
                return .failure(failure)
            case .success(let name):
                requestedName = name
                target = url.appendingPathComponent(name)
            }
        } else if url.pathExtension.lowercased() == "pdf" {
            // A full file path. Its folder still has to exist — we never create one.
            if nonEmpty(rawFilename) != nil {
                return .failure(.filenameAlongsideFilePath(trimmedPath))
            }
            let parent = url.deletingLastPathComponent()
            guard fileWriter.isDirectory(parent) else {
                return .failure(.missingParentDirectory(path: url.path, parent: parent.path))
            }
            requestedName = url.lastPathComponent
            target = url
        } else if fileWriter.fileExists(url) {
            return .failure(.notADirectory(url.path))
        } else {
            // Neither an existing folder nor recognisably a file name. Guessing which one
            // was meant is how a report ends up in the wrong place.
            return .failure(.missingDirectory(url.path))
        }

        return freeURL(near: target, requestedName: requestedName, fileWriter: fileWriter)
    }

    // MARK: - Private

    private static func filename(from raw: String?, default defaultName: String) -> Result<String, Failure> {
        guard let raw else { return .success(withPDFExtension(defaultName)) }
        guard let trimmed = nonEmpty(raw) else { return .failure(.emptyFilename) }
        guard !trimmed.contains("/") else { return .failure(.filenameWithSeparator(trimmed)) }
        return .success(withPDFExtension(trimmed))
    }

    private static func withPDFExtension(_ name: String) -> String {
        (name as NSString).pathExtension.lowercased() == "pdf" ? name : name + ".pdf"
    }

    /// Never overwrites: an existing file makes the next report "Name (2).pdf". A monthly
    /// skill re-run therefore cannot clobber a PDF that has already been invoiced from.
    private static func freeURL(
        near target: URL,
        requestedName: String,
        fileWriter: any MCPFileWriting
    ) -> Result<Resolved, Failure> {
        guard fileWriter.fileExists(target) else {
            return .success(Resolved(url: target, requestedFilename: requestedName))
        }

        let directory = target.deletingLastPathComponent()
        let base = (requestedName as NSString).deletingPathExtension
        let ext = (requestedName as NSString).pathExtension

        for attempt in 2...maximumCollisionAttempts {
            let candidate = directory.appendingPathComponent("\(base) (\(attempt)).\(ext)")
            if !fileWriter.fileExists(candidate) {
                return .success(Resolved(url: candidate, requestedFilename: requestedName))
            }
        }

        return .failure(.tooManyCollisions(requestedName))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
