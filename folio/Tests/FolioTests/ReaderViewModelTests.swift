import XCTest
import SwiftData
@testable import Folio

// MARK: - Tests

@MainActor
final class ReaderViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([Book.self, ReadingProgress.self, Bookmark.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - load()

    func test_load_populatesChapterURLs() async throws {
        let store = MockBookStore()
        let expectedURLs = [
            URL(string: "file:///tmp/ch1.html")!,
            URL(string: "file:///tmp/ch2.html")!
        ]
        store.chapterURLsResult = expectedURLs

        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 2)
        let vm = ReaderViewModel(book: book, store: store, context: context)

        XCTAssertTrue(vm.chapterURLs.isEmpty, "chapterURLs should start empty")
        await vm.load()
        XCTAssertEqual(vm.chapterURLs, expectedURLs, "load() should populate chapterURLs from store")
    }

    func test_load_restoresProgressFromBook() async throws {
        let store = MockBookStore()
        store.chapterURLsResult = [URL(string: "file:///tmp/ch1.html")!]

        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 3)
        let progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0.75)
        book.progress = progress
        context.insert(book)

        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()

        XCTAssertEqual(vm.currentChapterIndex, 2)
        XCTAssertEqual(vm.scrollFraction, 0.75, accuracy: 0.001)
    }

    // MARK: - saveProgress()

    func test_saveProgress_createsProgressIfNil() throws {
        let store = MockBookStore()
        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 3)
        context.insert(book)

        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.currentChapterIndex = 1
        vm.scrollFraction = 0.5

        XCTAssertNil(book.progress)
        vm.saveProgress()
        XCTAssertNotNil(book.progress)
        XCTAssertEqual(book.progress?.chapterIndex, 1)
        XCTAssertEqual(book.progress?.scrollFraction ?? 0, 0.5, accuracy: 0.001)
    }

    func test_saveProgress_updatesExistingProgress() throws {
        let store = MockBookStore()
        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 3)
        let progress = ReadingProgress(chapterIndex: 0, scrollFraction: 0.0)
        book.progress = progress
        context.insert(book)

        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.currentChapterIndex = 2
        vm.scrollFraction = 0.9
        vm.saveProgress()

        XCTAssertEqual(book.progress?.chapterIndex, 2)
        XCTAssertEqual(book.progress?.scrollFraction ?? 0, 0.9, accuracy: 0.001)
    }

    // MARK: - addBookmark()

    func test_addBookmark_appendsToBook() throws {
        let store = MockBookStore()
        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 3)
        context.insert(book)

        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.currentChapterIndex = 1
        vm.scrollFraction = 0.4

        XCTAssertTrue(book.bookmarks.isEmpty)
        vm.addBookmark(note: "A great passage")
        XCTAssertEqual(book.bookmarks.count, 1)
        XCTAssertEqual(book.bookmarks.first?.chapterIndex, 1)
        XCTAssertEqual(book.bookmarks.first?.note, "A great passage")
    }
}
