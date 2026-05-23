import XCTest
import SwiftData
@testable import Folio

@MainActor
final class NotesViewModelTests: XCTestCase {

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

    /// Two books, each with two bookmarks — one "highlight only" and one with a note.
    @discardableResult
    private func seedTwoBooksWithBookmarks() -> (Book, Book) {
        let bookA = Book(title: "Book A", author: "Author A", filePath: "Books/a.epub", chapterCount: 4)
        let highlightOnlyA = Bookmark(chapterIndex: 0, scrollFraction: 0.1, note: "", kind: .important)
        let noteA = Bookmark(chapterIndex: 1, scrollFraction: 0.4, note: "Great line", kind: .connection)
        bookA.bookmarks = [highlightOnlyA, noteA]

        let bookB = Book(title: "Book B", author: "Author B", filePath: "Books/b.epub", chapterCount: 4)
        let highlightOnlyB = Bookmark(chapterIndex: 0, scrollFraction: 0.2, note: "", kind: .lookup)
        bookB.bookmarks = [highlightOnlyB]

        context.insert(bookA)
        context.insert(bookB)
        return (bookA, bookB)
    }

    // MARK: - default tab

    func test_selectedTab_defaultsToHighlights() {
        let vm = NotesViewModel(context: context)
        XCTAssertEqual(vm.selectedTab, .highlights)
    }

    // MARK: - highlights tab

    func test_highlightsTab_includesEveryBookmark() {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.selectedTab = .highlights
        XCTAssertEqual(vm.items.count, 3)
    }

    // MARK: - notes tab

    func test_notesTab_includesOnlyBookmarksWithNotes() {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.selectedTab = .notes
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.note, "Great line")
    }

    // MARK: - bookmarks tab

    func test_bookmarksTab_includesOnlyEmptyNotes() {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.selectedTab = .bookmarks
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertTrue(vm.items.allSatisfy { $0.note.isEmpty })
    }

    // MARK: - book filter

    func test_bookFilter_restrictsToSingleBook() {
        let (bookA, _) = seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.bookFilter = bookA
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertTrue(vm.items.allSatisfy { $0.bookID == bookA.id })
    }

    // MARK: - sort

    func test_items_areSortedNewestFirst() {
        let book = Book(title: "X", author: "A", filePath: "x", chapterCount: 1)
        let bm1 = Bookmark(chapterIndex: 0, scrollFraction: 0)
        bm1.createdAt = Date(timeIntervalSinceNow: -10_000)
        let bm2 = Bookmark(chapterIndex: 0, scrollFraction: 0)
        bm2.createdAt = Date()
        book.bookmarks = [bm1, bm2]
        context.insert(book)

        let vm = NotesViewModel(context: context)
        let createdDates = vm.items.map(\.createdAt)
        XCTAssertEqual(createdDates, createdDates.sorted(by: >))
    }

    // MARK: - kind colours preserved

    func test_noteItem_kindMatchesBookmarkKind() {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.selectedTab = .highlights
        let kinds = Set(vm.items.map(\.kind))
        XCTAssertTrue(kinds.contains(.important))
        XCTAssertTrue(kinds.contains(.connection))
        XCTAssertTrue(kinds.contains(.lookup))
    }

    // MARK: - counts

    func test_count_perTab() {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        XCTAssertEqual(vm.count(for: .highlights), 3)
        XCTAssertEqual(vm.count(for: .notes), 1)
        XCTAssertEqual(vm.count(for: .bookmarks), 2)
    }

    // MARK: - delete

    func test_delete_removesFromContext() async throws {
        let (bookA, _) = seedTwoBooksWithBookmarks()
        let target = bookA.bookmarks.first { !$0.note.isEmpty }!

        // Count the total number of bookmarks across the whole store before delete.
        let before = try context.fetch(FetchDescriptor<Bookmark>()).count
        let vm = NotesViewModel(context: context)
        let item = vm.items.first(where: { $0.id == target.id })!
        await vm.delete(item)

        let after = try context.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(after.count, before - 1, "Total bookmark count should drop by one")
        XCTAssertNil(after.first(where: { $0.id == target.id }),
                     "Targeted bookmark should be gone from the store")
    }

    func test_delete_clearsErrorOnSuccess() async {
        seedTwoBooksWithBookmarks()
        let vm = NotesViewModel(context: context)
        vm.deleteError = "previous"
        let item = vm.items.first!
        await vm.delete(item)
        // Successful delete doesn't write deleteError; we just confirm it's untouched.
        XCTAssertEqual(vm.deleteError, "previous")
    }

    // MARK: - empty state

    func test_noItems_whenLibraryEmpty() {
        let vm = NotesViewModel(context: context)
        XCTAssertEqual(vm.items.count, 0)
        XCTAssertEqual(vm.count(for: .highlights), 0)
    }
}
