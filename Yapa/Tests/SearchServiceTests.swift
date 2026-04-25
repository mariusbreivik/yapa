import XCTest
@testable import Yapa

final class SearchServiceTests: XCTestCase {
    private let fileSystem = FileSystemService.shared
    private let searchService = SearchService.shared

    func testBuildFuzzyQueryStripsUnsupportedCharacters() {
        let query = buildFuzzySearchQuery("Hello, world! ~ crash??")
        XCTAssertEqual(query, "hello* world* crash*")
        XCTAssertFalse(query.contains("~"))
    }
    
    func testBuildFuzzyQueryDropsEmptyTerms() {
        let query = buildFuzzySearchQuery("   ...   ")
        XCTAssertEqual(query, "")
    }

    func testSearchFiltersResultsByTag() {
        let notes = [
            makeNote(title: "Project Plan", content: "Draft plan", tags: ["work"]),
            makeNote(title: "Project Plan", content: "Draft plan", tags: ["home"])
        ]

        fileSystem.allNotes = notes
        searchService.indexNotes(notes)

        let results = search("tag:work plan")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.note.tags, ["work"])
    }

    func testSearchFallsBackToFuzzyMatchWhenFTSFindsNothing() {
        let notes = [makeNote(title: "Project Plan", content: "draft plan", tags: [])]
        fileSystem.allNotes = notes
        searchService.indexNotes(notes)

        let results = search("pln")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.note.title, "Project Plan")
    }

    func testRecentSearchesKeepMostRecentFiveUniqueQueries() {
        let notes = [makeNote(title: "Alpha Beta Gamma Delta Epsilon Zeta", content: "alpha beta gamma delta epsilon zeta", tags: [])]
        fileSystem.allNotes = notes
        searchService.indexNotes(notes)
        searchService.clearRecentSearches()

        for query in ["alpha", "beta", "gamma", "delta", "epsilon", "beta"] {
            _ = search(query)
        }

        XCTAssertEqual(searchService.recentSearches, ["beta", "epsilon", "delta", "gamma", "alpha"])
    }

    private func search(_ query: String) -> [SearchResult] {
        let expectation = expectation(description: query)

        searchService.search(query: query)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        return searchService.searchResults
    }

    private func makeNote(title: String, content: String, tags: [String]) -> Note {
        Note(title: title, content: content, fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).md"), tags: tags)
    }
}
