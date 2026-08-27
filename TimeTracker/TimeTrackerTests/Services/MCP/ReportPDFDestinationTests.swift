import Testing
import Foundation
@testable import TimeTracker

struct ReportPDFDestinationTests {

    // MARK: - Fixtures

    private let defaultFilename = "Time Report - July 2026"

    private func makeWriter(
        directories: [String] = [],
        files: [String] = []
    ) -> MockMCPFileWriter {
        let writer = MockMCPFileWriter()
        writer.stubbedDirectories = Set(directories)
        writer.stubbedFiles = Set(files)
        return writer
    }

    private func resolve(
        path: String?,
        filename: String? = nil,
        writer: MockMCPFileWriter
    ) -> Result<ReportPDFDestination.Resolved, ReportPDFDestination.Failure> {
        ReportPDFDestination.resolve(
            path: path,
            filename: filename,
            defaultFilename: defaultFilename,
            fileWriter: writer
        )
    }

    private func resolved(
        path: String?,
        filename: String? = nil,
        writer: MockMCPFileWriter
    ) -> ReportPDFDestination.Resolved? {
        try? resolve(path: path, filename: filename, writer: writer).get()
    }

    private func failure(
        path: String?,
        filename: String? = nil,
        writer: MockMCPFileWriter
    ) -> ReportPDFDestination.Failure? {
        switch resolve(path: path, filename: filename, writer: writer) {
        case .failure(let failure): failure
        case .success: nil
        }
    }

    // MARK: - Folder destinations

    @Test func aFolderDestinationUsesThePeriodsDefaultFilename() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "/Users/test/Desktop", writer: writer)

        #expect(result?.filename == "Time Report - July 2026.pdf")
        #expect(result?.directory == "/Users/test/Desktop")
        #expect(result?.url.path == "/Users/test/Desktop/Time Report - July 2026.pdf")
        #expect(result?.renamedToAvoidOverwrite == false)
    }

    @Test func aTildeIsExpandedToTheHomeDirectory() {
        let desktop = NSHomeDirectory() + "/Desktop"
        let writer = makeWriter(directories: [desktop])

        let result = resolved(path: "~/Desktop", writer: writer)

        #expect(result?.directory == desktop)
        #expect(result?.url.path == desktop + "/Time Report - July 2026.pdf")
    }

    @Test func aTrailingSlashOnAFolderDoesNotProduceADoubleSeparator() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "/Users/test/Desktop/", writer: writer)

        #expect(result?.url.path == "/Users/test/Desktop/Time Report - July 2026.pdf")
    }

    @Test func surroundingWhitespaceInThePathIsIgnored() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "  /Users/test/Desktop  ", writer: writer)

        #expect(result?.directory == "/Users/test/Desktop")
    }

    // MARK: - Filename override

    @Test func aFilenameOverrideReplacesTheDefault() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "/Users/test/Desktop", filename: "invoice.pdf", writer: writer)

        #expect(result?.filename == "invoice.pdf")
    }

    @Test func aFilenameOverrideGainsThePDFExtensionWhenMissing() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "/Users/test/Desktop", filename: "invoice", writer: writer)

        #expect(result?.filename == "invoice.pdf")
    }

    @Test func anExistingUppercasePDFExtensionIsNotDoubled() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let result = resolved(path: "/Users/test/Desktop", filename: "Invoice.PDF", writer: writer)

        #expect(result?.filename == "Invoice.PDF")
    }

    @Test func aFilenameContainingASeparatorIsRejected() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        let failure = failure(path: "/Users/test/Desktop", filename: "reports/july.pdf", writer: writer)

        #expect(failure == .filenameWithSeparator("reports/july.pdf"))
        #expect(failure?.message.contains("destination_path") == true)
    }

    @Test func anEmptyFilenameIsRejectedRatherThanTreatedAsAbsent() {
        let writer = makeWriter(directories: ["/Users/test/Desktop"])

        #expect(failure(path: "/Users/test/Desktop", filename: "   ", writer: writer) == .emptyFilename)
    }

    // MARK: - Full file paths

    @Test func aFullPDFPathIsUsedAsGiven() {
        let writer = makeWriter(directories: ["/Users/test/Reports"])

        let result = resolved(path: "/Users/test/Reports/July.pdf", writer: writer)

        #expect(result?.url.path == "/Users/test/Reports/July.pdf")
        #expect(result?.filename == "July.pdf")
        #expect(result?.directory == "/Users/test/Reports")
    }

    @Test func aFullPathWhoseFolderIsMissingIsRejected() {
        let writer = makeWriter(directories: ["/Users/test"])

        let failure = failure(path: "/Users/test/Nope/July.pdf", writer: writer)

        #expect(failure == .missingParentDirectory(path: "/Users/test/Nope/July.pdf", parent: "/Users/test/Nope"))
        #expect(failure?.message.contains("/Users/test/Nope") == true)
    }

    /// Silently ignoring one of the two names the caller supplied is how a report ends up
    /// somewhere the caller does not expect.
    @Test func aFilenameAlongsideAFullFilePathIsRejectedRatherThanIgnored() {
        let writer = makeWriter(directories: ["/Users/test/Reports"])

        let failure = failure(path: "/Users/test/Reports/July.pdf", filename: "August.pdf", writer: writer)

        #expect(failure == .filenameAlongsideFilePath("/Users/test/Reports/July.pdf"))
    }

    // MARK: - Rejected paths

    @Test func aMissingPathIsRejected() {
        #expect(failure(path: nil, writer: makeWriter()) == .missingPath)
        #expect(failure(path: "   ", writer: makeWriter()) == .missingPath)
    }

    @Test func aRelativePathIsRejectedBecauseTheServerHasNoWorkingDirectory() {
        let failure = failure(path: "Desktop/report.pdf", writer: makeWriter())

        #expect(failure == .relativePath("Desktop/report.pdf"))
        #expect(failure?.message.contains("absolute") == true)
    }

    @Test func aFolderThatDoesNotExistIsRejectedRatherThanCreated() {
        let writer = makeWriter(directories: ["/Users/test"])

        let failure = failure(path: "/Users/test/NoSuchFolder", writer: writer)

        #expect(failure == .missingDirectory("/Users/test/NoSuchFolder"))
        #expect(writer.writeCallCount == 0)
    }

    @Test func anExistingNonPDFFileIsRejectedWithAMessageSayingWhy() {
        let writer = makeWriter(directories: ["/Users/test"], files: ["/Users/test/notes.txt"])

        let failure = failure(path: "/Users/test/notes.txt", writer: writer)

        #expect(failure == .notADirectory("/Users/test/notes.txt"))
        #expect(failure?.message.contains(".pdf") == true)
    }

    @Test func everyFailureMessageNamesAFix() {
        let failures: [ReportPDFDestination.Failure] = [
            .missingPath,
            .relativePath("x"),
            .missingDirectory("/x"),
            .missingParentDirectory(path: "/x/y.pdf", parent: "/x"),
            .notADirectory("/x"),
            .emptyFilename,
            .filenameWithSeparator("a/b"),
            .filenameAlongsideFilePath("/x/y.pdf"),
            .tooManyCollisions("y.pdf"),
        ]

        for failure in failures {
            #expect(!failure.message.isEmpty)
        }
    }

    // MARK: - Collisions

    @Test func anExistingFileIsNotOverwrittenButRenamed() {
        let writer = makeWriter(
            directories: ["/Users/test/Desktop"],
            files: ["/Users/test/Desktop/Time Report - July 2026.pdf"]
        )

        let result = resolved(path: "/Users/test/Desktop", writer: writer)

        #expect(result?.filename == "Time Report - July 2026 (2).pdf")
        #expect(result?.requestedFilename == "Time Report - July 2026.pdf")
        #expect(result?.renamedToAvoidOverwrite == true)
    }

    @Test func collisionsCountUpwardsUntilANameIsFree() {
        let writer = makeWriter(
            directories: ["/Users/test/Desktop"],
            files: [
                "/Users/test/Desktop/Time Report - July 2026.pdf",
                "/Users/test/Desktop/Time Report - July 2026 (2).pdf",
                "/Users/test/Desktop/Time Report - July 2026 (3).pdf",
            ]
        )

        #expect(resolved(path: "/Users/test/Desktop", writer: writer)?.filename == "Time Report - July 2026 (4).pdf")
    }

    @Test func aFullFilePathCollidesTheSameWay() {
        let writer = makeWriter(
            directories: ["/Users/test/Reports"],
            files: ["/Users/test/Reports/July.pdf"]
        )

        let result = resolved(path: "/Users/test/Reports/July.pdf", writer: writer)

        #expect(result?.filename == "July (2).pdf")
        #expect(result?.renamedToAvoidOverwrite == true)
    }

    @Test func exhaustingEveryCollisionAttemptFailsInsteadOfLoopingForever() {
        var taken = ["/Users/test/Desktop/Time Report - July 2026.pdf"]
        for attempt in 2...ReportPDFDestination.maximumCollisionAttempts {
            taken.append("/Users/test/Desktop/Time Report - July 2026 (\(attempt)).pdf")
        }
        let writer = makeWriter(directories: ["/Users/test/Desktop"], files: taken)

        #expect(failure(path: "/Users/test/Desktop", writer: writer) == .tooManyCollisions("Time Report - July 2026.pdf"))
    }
}
