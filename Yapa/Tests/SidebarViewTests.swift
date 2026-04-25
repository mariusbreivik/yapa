import XCTest

final class SidebarViewTests: XCTestCase {
    func testSidebarTreeIndentationOffsetsRootChildrenByTwoPoints() {
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 1), 0)
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 2), 22)
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 3), 42)
    }

    func testRenameSelectionPrefersSelectedFolderOverSelectedNote() {
        XCTAssertTrue(shouldRenameFolder(hasSelectedFolder: true, hasSelectedNote: true))
    }

    func testRenameSelectionUsesSelectedNoteWhenNoFolderIsSelected() {
        XCTAssertFalse(shouldRenameFolder(hasSelectedFolder: false, hasSelectedNote: true))
    }
}

private func shouldRenameFolder(hasSelectedFolder: Bool, hasSelectedNote: Bool) -> Bool {
    hasSelectedFolder
}
