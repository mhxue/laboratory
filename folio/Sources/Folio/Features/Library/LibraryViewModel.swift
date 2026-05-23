import Foundation
import Observation
import SwiftData

/// Concrete `@Observable` implementation of `LibraryViewModeling`.
@Observable
@MainActor
final class LibraryViewModel: LibraryViewModeling {

    // MARK: - LibraryViewModeling

    private(set) var books: [Book] = []
    var filter: LibraryFilter = .all
    var isImporting: Bool = false
    var importError: String?

    var filteredBooks: [Book] {
        switch filter {
        case .all:      return books
        case .reading:  return books.filter(\.isInProgress)
        case .finished: return books.filter(\.isFinished)
        case .unread:   return books.filter(\.isUnread)
        }
    }

    /// Highest-priority hero candidate: the most recently read in-progress
    /// book. We use `progress.lastRead` rather than `addedDate` so the hero
    /// follows what the user is actually engaging with.
    var continueReading: Book? {
        books
            .filter(\.isInProgress)
            .max(by: { lhs, rhs in
                let ld = lhs.progress?.lastRead ?? .distantPast
                let rd = rhs.progress?.lastRead ?? .distantPast
                return ld < rd
            })
    }

    func count(for filter: LibraryFilter) -> Int {
        switch filter {
        case .all:      return books.count
        case .reading:  return books.lazy.filter(\.isInProgress).count
        case .finished: return books.lazy.filter(\.isFinished).count
        case .unread:   return books.lazy.filter(\.isUnread).count
        }
    }

    // MARK: - Dependencies

    private let store: any BookStoring
    private let context: ModelContext

    // MARK: - Init

    init(store: any BookStoring, context: ModelContext) {
        self.store = store
        self.context = context
        fetchBooks()
    }

    // MARK: - Actions

    func importBook(from url: URL) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        do {
            _ = try store.importBook(from: url, context: context)
            fetchBooks()
        } catch {
            importError = error.localizedDescription
        }
    }

    func deleteBook(_ book: Book) async {
        do {
            try store.deleteBook(book, context: context)
            fetchBooks()
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func fetchBooks() {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])
        books = (try? context.fetch(descriptor)) ?? []
    }
}
