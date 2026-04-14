import XCTest

final class SearchServiceTests: XCTestCase {
    func testBuildFuzzyQueryStripsUnsupportedCharacters() {
        let query = buildFuzzySearchQuery("Hello, world! ~ crash??")
        XCTAssertEqual(query, "hello* world* crash*")
        XCTAssertFalse(query.contains("~"))
    }
    
    func testBuildFuzzyQueryDropsEmptyTerms() {
        let query = buildFuzzySearchQuery("   ...   ")
        XCTAssertEqual(query, "")
    }
}
