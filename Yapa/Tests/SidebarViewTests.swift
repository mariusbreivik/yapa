import XCTest

final class SidebarViewTests: XCTestCase {
    func testSidebarTreeIndentationOffsetsRootChildrenByTwoPoints() {
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 1), 0)
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 2), 22)
        XCTAssertEqual(sidebarTreeLeadingPadding(forDepth: 3), 42)
    }
}
