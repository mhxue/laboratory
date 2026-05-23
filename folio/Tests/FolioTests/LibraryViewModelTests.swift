import XCTest
import SwiftData
@testable import Folio

// MARK: - Mock BookStoring

@MainActor
final class MockBookStore: BookStoring {
    var importedBooks: [Book] = []
    var deletedBooks: [Book] = []
    var shouldThrowOnImport = false
    var shouldThrowOnDelete = false
    var chapterURLsResult: [URL] = []

    func importBook(from url: URL, context: ModelContext) throws -> Book {
        if shouldThrowOnImport {
            throw TestError.intentional
        }
        let book = Book(title: "Mock Book", author: "Mock Author", filePath: "Books/mock.epub", chapterCount: 3)
        importedBooks.append(book)
        return book
    }

    func deleteBook(_ book: Book, context: ModelContext) throws {
        if shouldThrowOnDelete {
            throw TestError.intentional
        }
        deletedBooks.append(book)
    }

    func chapterURLs(for book: Book) throws -> [URL] {
        chapterURLsResult
    }

    func coverImage(for book: Book) -> UIImage? { nil }
}

enum TestError: Error {
    case intentional
}

// MARK: - Tests

@MainActor
final class LibraryViewModelTests: XCTestCase {

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

    // MARK: - importBook

    func test_importBook_setsIsImporting_thenClears() async {
        let store = MockBookStore()
        let vm = LibraryViewModel(store: store, context: context)

        // isImporting should start false
        XCTAssertFalse(vm.isImporting)

        // After the async call completes it should be false again
        await vm.importBook(from: URL(string: "file:///tmp/test.epub")!)
        XCTAssertFalse(vm.isImporting)
    }

    func test_importBook_success_clearsImportError() async {
        let store = MockBookStore()
        let vm = LibraryViewModel(store: store, context: context)
        vm.importError = "previous error"

        await vm.importBook(from: URL(string: "file:///tmp/test.epub")!)

        // Successful import should not surface an error
        XCTAssertNil(vm.importError)
    }

    func test_importBook_failure_setsImportError() async {
        let store = MockBookStore()
        store.shouldThrowOnImport = true
        let vm = LibraryViewModel(store: store, context: context)

        await vm.importBook(from: URL(string: "file:///tmp/test.epub")!)

        XCTAssertNotNil(vm.importError, "Expected importError to be set after failed import")
        XCTAssertFalse(vm.isImporting, "isImporting should be false after failure")
    }

    // MARK: - deleteBook

    func test_deleteBook_callsStoreDelete() async {
        let store = MockBookStore()
        let vm = LibraryViewModel(store: store, context: context)
        let book = Book(title: "To Delete", author: "Author", filePath: "Books/x.epub", chapterCount: 1)

        await vm.deleteBook(book)

        XCTAssertTrue(store.deletedBooks.contains(where: { $0.title == book.title }),
                      "Store should have received a delete call for the book")
    }

    func test_deleteBook_failure_setsImportError() async {
        let store = MockBookStore()
        store.shouldThrowOnDelete = true
        let vm = LibraryViewModel(store: store, context: context)
        let book = Book(title: "Bad Delete", author: "Author", filePath: "Books/y.epub", chapterCount: 1)

        await vm.deleteBook(book)

        XCTAssertNotNil(vm.importError)
    }

    // MARK: - filters

    /// Inserts three books (unread / reading / finished) into the in-memory
    /// SwiftData context, then reloads the VM so `fetchBooks` picks them up.
    @discardableResult
    private func seedThreeBooks() -> (unread: Book, reading: Book, finished: Book) {
        let unread = Book(title: "Unread", author: "A", filePath: "Books/u.epub", chapterCount: 4)
        let reading = Book(title: "Reading", author: "A", filePath: "Books/r.epub", chapterCount: 4)
        reading.progress = ReadingProgress(chapterIndex: 1, scrollFraction: 0.5)
        let finished = Book(title: "Finished", author: "A", filePath: "Books/f.epub", chapterCount: 2)
        finished.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0)
        context.insert(unread)
        context.insert(reading)
        context.insert(finished)
        return (unread, reading, finished)
    }

    func test_filter_all_returnsEverything() {
        let seeded = seedThreeBooks()
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        vm.filter = .all
        XCTAssertEqual(Set(vm.filteredBooks.map(\.title)),
                       Set([seeded.unread.title, seeded.reading.title, seeded.finished.title]))
    }

    func test_filter_reading_returnsOnlyInProgress() {
        let seeded = seedThreeBooks()
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        vm.filter = .reading
        XCTAssertEqual(vm.filteredBooks.map(\.title), [seeded.reading.title])
    }

    func test_filter_finished_returnsOnlyFinished() {
        let seeded = seedThreeBooks()
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        vm.filter = .finished
        XCTAssertEqual(vm.filteredBooks.map(\.title), [seeded.finished.title])
    }

    func test_filter_unread_returnsOnlyUnread() {
        let seeded = seedThreeBooks()
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        vm.filter = .unread
        XCTAssertEqual(vm.filteredBooks.map(\.title), [seeded.unread.title])
    }

    func test_count_perFilter() {
        seedThreeBooks()
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        XCTAssertEqual(vm.count(for: .all), 3)
        XCTAssertEqual(vm.count(for: .reading), 1)
        XCTAssertEqual(vm.count(for: .finished), 1)
        XCTAssertEqual(vm.count(for: .unread), 1)
    }

    // MARK: - continueReading hero

    func test_continueReading_isNil_whenLibraryEmpty() {
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        XCTAssertNil(vm.continueReading)
    }

    func test_continueReading_isNil_whenNoInProgressBook() {
        // Only unread + finished.
        let unread = Book(title: "U", author: "A", filePath: "Books/u.epub", chapterCount: 2)
        let finished = Book(title: "F", author: "A", filePath: "Books/f.epub", chapterCount: 2)
        finished.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0)
        context.insert(unread)
        context.insert(finished)
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        XCTAssertNil(vm.continueReading)
    }

    func test_continueReading_prefersMostRecentlyRead() {
        let older = Book(title: "Older", author: "A", filePath: "Books/o.epub", chapterCount: 4)
        let p1 = ReadingProgress(chapterIndex: 1, scrollFraction: 0.3)
        p1.lastRead = Date(timeIntervalSinceNow: -3600)
        older.progress = p1

        let newer = Book(title: "Newer", author: "A", filePath: "Books/n.epub", chapterCount: 4)
        let p2 = ReadingProgress(chapterIndex: 2, scrollFraction: 0.2)
        p2.lastRead = Date()
        newer.progress = p2

        context.insert(older)
        context.insert(newer)

        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        XCTAssertEqual(vm.continueReading?.title, "Newer")
    }

    func test_filter_defaultsToAll() {
        let vm = LibraryViewModel(store: MockBookStore(), context: context)
        XCTAssertEqual(vm.filter, .all)
    }
}
