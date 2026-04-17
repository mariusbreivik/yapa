import XCTest
@testable import Yapa

final class AppVersionTests: XCTestCase {
    func testDisplayStringFormatsVersionAndBuild() {
        let version = AppVersionInfo(marketingVersion: "1.2.3", buildNumber: "45")

        XCTAssertEqual(version.displayString, "v1.2.3 (45)")
    }
}
