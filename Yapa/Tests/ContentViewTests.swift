import XCTest
@testable import Yapa

final class ContentViewTests: XCTestCase {
    func testProjectRootHelperFindsParentProjectForNestedFolder() {
        let root = URL(fileURLWithPath: "/tmp/yapa")
        let project = FolderItem(name: "Project", url: root.appendingPathComponent("Project", isDirectory: true))
        let nested = root.appendingPathComponent("Project/Notes/Today", isDirectory: true)

        let result = projectRoot(containing: nested, in: [project])

        XCTAssertEqual(result?.name, "Project")
    }

    func testProjectRootHelperReturnsNilOutsideProjects() {
        let project = FolderItem(name: "Project", url: URL(fileURLWithPath: "/tmp/yapa/Project", isDirectory: true))
        let outside = URL(fileURLWithPath: "/tmp/yapa/Other", isDirectory: true)

        XCTAssertNil(projectRoot(containing: outside, in: [project]))
    }
}
