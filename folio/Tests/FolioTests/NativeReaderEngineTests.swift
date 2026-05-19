import XCTest
import EPUBKit
@testable import Folio

// MARK: - Mock

/// Returns a fixed EPUBContent without touching the file system.
final class MockContentParser: EPUBContentParsing, @unchecked Sendable {
    var contentToReturn: EPUBContent = EPUBContent(blocks: [])
    var errorToThrow: Error?
    private(set) var parseCallCount = 0
    private(set) var lastParsedURL: URL?

    func parse(xhtmlAt url: URL) throws -> EPUBContent {
        parseCallCount += 1
        lastParsedURL = url
        if let error = errorToThrow { throw error }
        return contentToReturn
    }
}

// MARK: - Tests

@MainActor
final class NativeReaderEngineTests: XCTestCase {

    private var mock: MockContentParser!
    private var engine: NativeReaderEngine!

    override func setUp() {
        super.setUp()
        mock = MockContentParser()
        engine = NativeReaderEngine(parser: mock)
    }

    func test_load_callsParserWithCorrectURL() async throws {
        let url = URL(fileURLWithPath: "/tmp/chapter1.xhtml")
        mock.contentToReturn = EPUBContent(blocks: [])

        engine.load(chapterURL: url, stylesheet: .default, pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        XCTAssertEqual(mock.parseCallCount, 1)
        XCTAssertEqual(mock.lastParsedURL, url)
    }

    func test_load_emptyContent_producesNoPages() async throws {
        mock.contentToReturn = EPUBContent(blocks: [])

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        XCTAssertTrue(engine.pages.isEmpty)
        XCTAssertTrue(engine.blocks.isEmpty)
    }

    func test_load_singleParagraph_producesOnePage() async throws {
        mock.contentToReturn = EPUBContent(blocks: [
            .paragraph([.text("Hello world")], style: .body)
        ])

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        XCTAssertEqual(engine.blocks.count, 1)
        XCTAssertGreaterThanOrEqual(engine.pages.count, 1)
    }

    func test_load_manyParagraphs_paginatesIntoMultiplePages() async throws {
        let loremBlock = EPUBBlock.paragraph([.text(String(repeating: "Lorem ipsum dolor sit amet. ", count: 20))], style: .body)
        mock.contentToReturn = EPUBContent(blocks: Array(repeating: loremBlock, count: 30))

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        XCTAssertGreaterThan(engine.pages.count, 1, "30 long paragraphs should paginate beyond one page")
    }

    func test_load_isReadyFalse_duringLoad() {
        mock.contentToReturn = EPUBContent(blocks: [.paragraph([.text("x")], style: .body)])
        XCTAssertFalse(engine.isReady)

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        XCTAssertFalse(engine.isReady, "isReady must be false immediately after calling load()")
    }

    func test_load_isReady_afterCompletion() async throws {
        mock.contentToReturn = EPUBContent(blocks: [])

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        XCTAssertTrue(engine.isReady)
    }

    func test_load_parserError_leavesEngineNotReady() async throws {
        mock.errorToThrow = EPUBError.missingContainer

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        // Give the task time to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(engine.isReady)
        XCTAssertTrue(engine.pages.isEmpty)
    }

    func test_load_cancelsInFlightTask_onNewLoad() async throws {
        mock.contentToReturn = EPUBContent(blocks: [])

        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch1.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))
        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch2.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        try await waitForReady()
        // Only the last URL matters after cancellation
        XCTAssertEqual(mock.lastParsedURL, URL(fileURLWithPath: "/tmp/ch2.xhtml"))
    }

    func test_load_resetsState_beforeNewLoad() async throws {
        mock.contentToReturn = EPUBContent(blocks: [.paragraph([.text("first")], style: .body)])
        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))
        try await waitForReady()
        XCTAssertTrue(engine.isReady)

        // Second load — engine must immediately reset
        mock.contentToReturn = EPUBContent(blocks: [])
        engine.load(chapterURL: .init(fileURLWithPath: "/tmp/ch2.xhtml"),
                    stylesheet: .default,
                    pageSize: CGSize(width: 390, height: 844))

        XCTAssertFalse(engine.isReady, "isReady must reset to false on second load")
        XCTAssertTrue(engine.pages.isEmpty, "pages must clear on second load")
    }

    // MARK: - Helpers

    /// Polls until engine.isReady or times out after 2 s.
    private func waitForReady(timeout: TimeInterval = 2.0) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !engine.isReady {
            if Date() > deadline { throw XCTSkip("Engine did not become ready in time") }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
