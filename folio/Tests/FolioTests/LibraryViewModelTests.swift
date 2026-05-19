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
}
