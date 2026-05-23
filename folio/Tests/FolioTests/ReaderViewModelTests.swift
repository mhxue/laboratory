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
        vm.addBookmark(note: "A great passage", kind: .important)
        XCTAssertEqual(book.bookmarks.count, 1)
        XCTAssertEqual(book.bookmarks.first?.chapterIndex, 1)
        XCTAssertEqual(book.bookmarks.first?.note, "A great passage")
        XCTAssertEqual(book.bookmarks.first?.kind, .important)
    }

    func test_addBookmark_recordsKind() throws {
        let store = MockBookStore()
        let book = Book(title: "Test Book", author: "Author", filePath: "Books/x.epub", chapterCount: 3)
        context.insert(book)

        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.addBookmark(note: "see ch 1", kind: .connection)
        XCTAssertEqual(book.bookmarks.first?.kind, .connection)
    }

    // MARK: - overallProgress

    func test_overallProgress_isZero_whenNoChapters() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 0)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        XCTAssertEqual(vm.overallProgress, 0)
    }

    func test_overallProgress_atChapterStart() async {
        let store = MockBookStore()
        store.chapterURLsResult = (0..<4).map { URL(string: "file:///ch\($0).html")! }
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 4)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()
        vm.currentChapterIndex = 2
        vm.currentPage = 0
        vm.totalPages = 10
        XCTAssertEqual(vm.overallProgress, 0.5, accuracy: 1e-6)
    }

    func test_overallProgress_midChapter_combinesPageFraction() async {
        let store = MockBookStore()
        store.chapterURLsResult = (0..<4).map { URL(string: "file:///ch\($0).html")! }
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 4)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()
        vm.currentChapterIndex = 1
        vm.totalPages = 10
        vm.currentPage = 5  // half-way through chapter 1
        // (1 + 0.5) / 4 = 0.375
        XCTAssertEqual(vm.overallProgress, 0.375, accuracy: 1e-6)
    }

    func test_overallProgress_isClamped() async {
        let store = MockBookStore()
        store.chapterURLsResult = (0..<2).map { URL(string: "file:///ch\($0).html")! }
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 2)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()
        vm.currentChapterIndex = 5
        vm.currentPage = 100
        vm.totalPages = 10
        XCTAssertLessThanOrEqual(vm.overallProgress, 1.0)
        XCTAssertGreaterThanOrEqual(vm.overallProgress, 0.0)
    }

    // MARK: - setOverallProgress (scrubber)

    func test_setOverallProgress_movesCurrentChapterAndPage() async {
        let store = MockBookStore()
        store.chapterURLsResult = (0..<4).map { URL(string: "file:///ch\($0).html")! }
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 4)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()
        vm.totalPages = 10

        vm.setOverallProgress(0.5) // -> chapter 2 at start
        XCTAssertEqual(vm.currentChapterIndex, 2)
        XCTAssertEqual(vm.currentPage, 0)

        vm.setOverallProgress(0.625) // -> chapter 2, halfway through (0.5 within chapter)
        XCTAssertEqual(vm.currentChapterIndex, 2)
        XCTAssertEqual(vm.currentPage, 5)
    }

    func test_setOverallProgress_clampsTo01() async {
        let store = MockBookStore()
        store.chapterURLsResult = (0..<2).map { URL(string: "file:///ch\($0).html")! }
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 2)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        await vm.load()
        vm.totalPages = 10

        vm.setOverallProgress(-5)
        XCTAssertEqual(vm.currentChapterIndex, 0)
        XCTAssertEqual(vm.currentPage, 0)

        vm.setOverallProgress(5)
        XCTAssertLessThanOrEqual(vm.currentChapterIndex, 1)
    }

    func test_setOverallProgress_isNoop_whenNoChapters() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 0)
        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.setOverallProgress(0.5)
        XCTAssertEqual(vm.currentChapterIndex, 0)
        XCTAssertEqual(vm.currentPage, 0)
    }

    // MARK: - Chrome auto-hide

    func test_revealChromeAndScheduleHide_setsVisibleImmediately() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        let vm = ReaderViewModel(book: book, store: store, context: context, chromeAutoHideDelay: 60)
        vm.showChrome = false
        vm.revealChromeAndScheduleHide()
        XCTAssertTrue(vm.showChrome)
        vm.cancelChromeAutoHide()
    }

    func test_chromeAutoHide_hidesAfterDelay() async throws {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        // Very short delay so the test is deterministic.
        let vm = ReaderViewModel(book: book, store: store, context: context, chromeAutoHideDelay: 0.05)
        vm.revealChromeAndScheduleHide()
        XCTAssertTrue(vm.showChrome)
        // Wait a bit more than the delay to allow the timer task to run.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(vm.showChrome, "Chrome should auto-hide after delay")
    }

    func test_cancelChromeAutoHide_preventsHiding() async throws {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        let vm = ReaderViewModel(book: book, store: store, context: context, chromeAutoHideDelay: 0.05)
        vm.revealChromeAndScheduleHide()
        vm.cancelChromeAutoHide()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(vm.showChrome, "Cancelling auto-hide should keep chrome visible")
    }

    func test_toggleChrome_flipsState() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        let vm = ReaderViewModel(book: book, store: store, context: context, chromeAutoHideDelay: 60)
        vm.showChrome = true
        vm.toggleChrome()
        XCTAssertFalse(vm.showChrome)
        vm.toggleChrome()
        XCTAssertTrue(vm.showChrome)
        vm.cancelChromeAutoHide()
    }

    // MARK: - Time-left label

    func test_timeLeftLabel_isFormatted_whenPaceAvailable() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        // Use the default fallback pace (220 wpm) so the label resolves immediately.
        let vm = ReaderViewModel(book: book, store: store, context: context)
        vm.wordsRemaining = 13_200  // 60 min at 220 wpm
        XCTAssertEqual(vm.timeLeftLabel, "1h left")
    }

    func test_timeLeftLabel_isNil_withoutPaceOrFallback() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        let vm = ReaderViewModel(book: book,
                                 store: store,
                                 context: context,
                                 paceTracker: ReadingPaceTracker())  // no fallback
        vm.wordsRemaining = 5000
        XCTAssertNil(vm.timeLeftLabel)
    }

    func test_recordPageRead_feedsThePaceTracker() {
        let store = MockBookStore()
        let book = Book(title: "B", author: "A", filePath: "p", chapterCount: 1)
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        let vm = ReaderViewModel(book: book, store: store, context: context, paceTracker: tracker)
        vm.recordPageRead(words: 200, duration: 60)
        XCTAssertEqual(tracker.sampleCount, 1)
        XCTAssertEqual(tracker.wordsPerMinute ?? 0, 200, accuracy: 0.5)
    }
}
