import XCTest
@testable import Yapa

final class FileSystemServiceTests: XCTestCase {
    func testLoadNoteParsesTagsFromFrontmatter() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let noteURL = rootURL.appendingPathComponent("tagged.md")
        let content = """
        ---
        title: "Tagged Note"
        created: 2026-04-12T10:00:00Z
        modified: 2026-04-12T10:01:00Z
        tags: [work, ideas, "deep focus"]
        ---

        Body text.
        """
        try content.write(to: noteURL, atomically: true, encoding: .utf8)

        let service = FileSystemService(fileManager: .default)
        let note = try XCTUnwrap(service.loadNote(from: noteURL))

        XCTAssertEqual(note.tags, ["work", "ideas", "deep focus"])
    }

    func testSaveNotePersistsTagsToFrontmatter() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let noteURL = rootURL.appendingPathComponent("saved.md")
        let note = Note(
            title: "Saved Note",
            content: "Body text.",
            createdAt: Date(timeIntervalSince1970: 1000),
            modifiedAt: Date(timeIntervalSince1970: 2000),
            fileURL: noteURL,
            tags: ["work", "ideas"]
        )

        let service = FileSystemService(fileManager: .default)
        service.saveNote(note)

        let savedContent = try String(contentsOf: noteURL, encoding: .utf8)
        XCTAssertTrue(savedContent.contains("tags: [\"work\", \"ideas\"]"))
    }

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
        tags: [work]
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
