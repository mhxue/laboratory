import Foundation
import Observation
import SwiftData

/// Concrete `@Observable` implementation of `ReaderViewModeling`.
@Observable
@MainActor
final class ReaderViewModel: ReaderViewModeling {

    // MARK: - ReaderViewModeling

    private(set) var chapterURLs: [URL] = []
    var currentChapterIndex: Int = 0
    var scrollFraction: Double = 0
    var showChrome: Bool = true
    private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let book: Book
    private let store: any BookStoring
    private let context: ModelContext

    // MARK: - Init

    init(book: Book, store: any BookStoring, context: ModelContext) {
        self.book = book
        self.store = store
        self.context = context
    }

    // MARK: - ReaderViewModeling

    func load() async {
        isLoading = true
        defer { isLoading = false }
        chapterURLs = (try? store.chapterURLs(for: book)) ?? []
        if let p = book.progress {
            currentChapterIndex = p.chapterIndex
            scrollFraction = p.scrollFraction
        }
    }

    func saveProgress() {
        if book.progress == nil {
            let p = ReadingProgress(chapterIndex: currentChapterIndex, scrollFraction: scrollFraction)
            book.progress = p
        } else {
            book.progress?.chapterIndex = currentChapterIndex
            book.progress?.scrollFraction = scrollFraction
            book.progress?.lastRead = Date()
        }
        try? context.save()
    }

    func addBookmark(note: String) {
        let bookmark = Bookmark(
            chapterIndex: currentChapterIndex,
            scrollFraction: scrollFraction,
            note: note
        )
        book.bookmarks.append(bookmark)
        try? context.save()
    }
}
