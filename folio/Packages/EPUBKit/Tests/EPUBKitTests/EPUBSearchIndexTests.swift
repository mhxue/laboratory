import XCTest
@testable import EPUBKit

final class EPUBSearchIndexTests: XCTestCase {

    // MARK: - Helpers

    private func makeIndex(chapters: [(Int, EPUBContent)]) -> EPUBSearchIndex {
        EPUBSearchIndex.build(from: chapters.map { (index: $0.0, content: $0.1) })
    }

    private func singleChapter(_ blocks: [EPUBBlock]) -> [(Int, EPUBContent)] {
        [(0, EPUBContent(blocks: blocks))]
    }

    // MARK: - test_search_findsExactWord

    func test_search_findsExactWord() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("The quick brown fox jumps")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))
        let results = idx.search("quick")
        XCTAssertFalse(results.isEmpty, "Should find exact word 'quick'")
        XCTAssertEqual(results.first?.address.chapterIndex, 0)
        XCTAssertEqual(results.first?.address.blockIndex, 0)
    }

    // MARK: - test_search_caseInsensitive

    func test_search_caseInsensitive() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("Elizabeth Bennet was proud")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))

        let lower = idx.search("elizabeth")
        let upper = idx.search("ELIZABETH")
        let mixed = idx.search("Elizabeth")

        XCTAssertFalse(lower.isEmpty, "Lowercase query should find match")
        XCTAssertFalse(upper.isEmpty, "Uppercase query should find match")
        XCTAssertFalse(mixed.isEmpty, "Mixed-case query should find match")

        XCTAssertEqual(lower.count, upper.count)
        XCTAssertEqual(lower.count, mixed.count)
    }

    // MARK: - test_search_returnsSnippet

    func test_search_returnsSnippet() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("It is a truth universally acknowledged that a single man in possession of a good fortune must be in want of a wife.")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))
        let results = idx.search("universally")
        XCTAssertFalse(results.isEmpty)
        let snippet = results.first!.snippet
        XCTAssertFalse(snippet.isEmpty, "Snippet should not be empty")
        // The snippet should contain the query word (case may vary)
        XCTAssertTrue(snippet.lowercased().contains("universally"), "Snippet should contain the search term")
    }

    // MARK: - test_search_emptyQuery_returnsEmpty

    func test_search_emptyQuery_returnsEmpty() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("Some text here")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))

        XCTAssertTrue(idx.search("").isEmpty, "Empty query should return empty results")
        XCTAssertTrue(idx.search("   ").isEmpty, "Whitespace-only query should return empty results")
    }

    // MARK: - test_search_acrossChapters

    func test_search_acrossChapters() {
        let chapter0 = EPUBContent(blocks: [
            .paragraph([.text("Darcy entered the room")], style: .body)
        ])
        let chapter1 = EPUBContent(blocks: [
            .paragraph([.text("Darcy spoke carefully to Jane")], style: .body)
        ])
        let idx = makeIndex(chapters: [(0, chapter0), (1, chapter1)])
        let results = idx.search("Darcy")

        XCTAssertEqual(results.count, 2, "Should find 'Darcy' in both chapters")
        let chapterIndices = Set(results.map { $0.address.chapterIndex })
        XCTAssertTrue(chapterIndices.contains(0))
        XCTAssertTrue(chapterIndices.contains(1))

        // Results must be sorted by address
        for i in 0..<(results.count - 1) {
            XCTAssertLessThanOrEqual(results[i].address, results[i + 1].address)
        }
    }

    // MARK: - No match

    func test_search_noMatch_returnsEmpty() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("Nothing relevant here")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))
        XCTAssertTrue(idx.search("Darcy").isEmpty)
    }

    // MARK: - Multi-word substring

    func test_search_multiWordSubstring() {
        let blocks: [EPUBBlock] = [
            .paragraph([.text("She was a woman of mean understanding")], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))
        let results = idx.search("mean understanding")
        XCTAssertFalse(results.isEmpty, "Should find multi-word phrase")
    }

    // MARK: - Emphasis inline search

    func test_search_withinEmphasisInline() {
        let blocks: [EPUBBlock] = [
            .paragraph([.emphasis([.text("hidden")])], style: .body)
        ]
        let idx = makeIndex(chapters: singleChapter(blocks))
        let results = idx.search("hidden")
        XCTAssertFalse(results.isEmpty, "Should find text inside emphasis inline")
    }
}
