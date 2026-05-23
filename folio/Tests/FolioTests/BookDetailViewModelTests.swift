import XCTest
import SwiftData
@testable import Folio

/// In-memory file locator: lets us assert on `fileSize` formatting and
/// chapter list state without touching disk.
struct FakeFileLocator: BookFileLocating {
    var files: [String: Int64] = [:]   // relative path -> byte size

    func absoluteURL(for relativePath: String) -> URL? {
        URL(fileURLWithPath: "/tmp/fake-folio/" + relativePath)
    }

    func fileSize(at url: URL) -> Int64? {
        let key = url.path.replacingOccurrences(of: "/tmp/fake-folio/", with: "")
        return files[key]
    }
}

@MainActor
final class BookDetailViewModelTests: XCTestCase {

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

    // MARK: - fileSizeFormatted

    func test_fileSizeFormatted_isDashed_whenFileMissing() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertEqual(vm.fileSizeFormatted, "—")
    }

    func test_fileSizeFormatted_humanReadable() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let locator = FakeFileLocator(files: ["Books/x.epub": 2_400_000])
        let vm = BookDetailViewModel(book: book, locator: locator)
        // ByteCountFormatter output varies slightly by locale, but the value
        // should never be the fallback "—".
        XCTAssertNotEqual(vm.fileSizeFormatted, "—")
        XCTAssertTrue(vm.fileSizeFormatted.contains("MB"))
    }

    // MARK: - isStoredLocally

    func test_isStoredLocally_falseWhenMissing() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertFalse(vm.isStoredLocally)
    }

    func test_isStoredLocally_trueWhenPresent() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let locator = FakeFileLocator(files: ["Books/x.epub": 1000])
        let vm = BookDetailViewModel(book: book, locator: locator)
        XCTAssertTrue(vm.isStoredLocally)
    }

    // MARK: - chapters

    func test_chapters_empty_whenChapterCountZero() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 0)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertTrue(vm.chapters.isEmpty)
    }

    func test_chapters_areGeneratedFromCount() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 3)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertEqual(vm.chapters.map(\.id), [0, 1, 2])
        XCTAssertEqual(vm.chapters.map(\.title), ["Chapter 1", "Chapter 2", "Chapter 3"])
    }

    func test_chapters_markCurrentChapter() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0.3)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        let currentFlags = vm.chapters.map(\.isCurrent)
        XCTAssertEqual(currentFlags, [false, false, true, false])
    }

    func test_chapters_markReadChapters_beforeCurrent() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0.3)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        let readFlags = vm.chapters.map(\.isRead)
        XCTAssertEqual(readFlags, [true, true, false, false])
    }

    func test_chapters_unread_whenNoProgress() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 3)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertTrue(vm.chapters.allSatisfy { !$0.isCurrent && !$0.isRead })
    }

    // MARK: - exportURL

    func test_exportURL_isNil_whenFileMissing() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let vm = BookDetailViewModel(book: book, locator: FakeFileLocator())
        XCTAssertNil(vm.exportURL())
    }

    func test_exportURL_returnsAbsoluteURL_whenPresent() {
        let book = Book(title: "B", author: "A", filePath: "Books/x.epub", chapterCount: 1)
        let locator = FakeFileLocator(files: ["Books/x.epub": 1024])
        let vm = BookDetailViewModel(book: book, locator: locator)
        XCTAssertEqual(vm.exportURL()?.path, "/tmp/fake-folio/Books/x.epub")
    }
}
