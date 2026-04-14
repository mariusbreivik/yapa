import XCTest

final class FileSystemServiceTests: XCTestCase {
    func testMoveNoteUpdatesFolderStructureAndRootNotes() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let archiveURL = rootURL.appendingPathComponent("Archive", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)

        let rootNoteURL = rootURL.appendingPathComponent("2026-04-12-root.md")
        let noteContents = """
        ---
        title: "Root Note"
        created: 2026-04-12T10:00:00Z
        modified: 2026-04-12T10:01:00Z
        pinned: false
        lastAccessed: 2026-04-12T10:02:00Z
        ---

        # Root Note

        Body text.
        """
        try noteContents.write(to: rootNoteURL, atomically: true, encoding: .utf8)

        let movedIntoFolderURL = try moveNoteFile(at: rootNoteURL, to: archiveURL)
        let folderNoteURL = archiveURL.appendingPathComponent(rootNoteURL.lastPathComponent)

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootNoteURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderNoteURL.path))
        XCTAssertEqual(movedIntoFolderURL.standardizedFileURL, folderNoteURL.standardizedFileURL)
        XCTAssertEqual(notesDirectlyInRoot(at: rootURL), [])
        XCTAssertEqual(notesDirectlyInFolder(at: archiveURL), [folderNoteURL.lastPathComponent])

        let movedBackToRootURL = try moveNoteFile(at: folderNoteURL, to: rootURL)
        let rootMovedURL = rootURL.appendingPathComponent(folderNoteURL.lastPathComponent)

        XCTAssertTrue(FileManager.default.fileExists(atPath: rootMovedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folderNoteURL.path))
        XCTAssertEqual(movedBackToRootURL.standardizedFileURL, rootMovedURL.standardizedFileURL)
        XCTAssertEqual(notesDirectlyInRoot(at: rootURL), [rootMovedURL.lastPathComponent])
        XCTAssertEqual(notesDirectlyInFolder(at: archiveURL), [])
    }

    private func moveNoteFile(at sourceURL: URL, to destinationFolder: URL) throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func notesDirectlyInRoot(at rootURL: URL) -> [String] {
        notesDirectlyInFolder(at: rootURL)
    }

    private func notesDirectlyInFolder(at folderURL: URL) -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "md" }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
