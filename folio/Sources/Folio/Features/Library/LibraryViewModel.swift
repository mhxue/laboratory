import Foundation
import Observation
import SwiftData

/// Concrete `@Observable` implementation of `LibraryViewModeling`.
@Observable
@MainActor
final class LibraryViewModel: LibraryViewModeling {

    // MARK: - LibraryViewModeling

    private(set) var books: [Book] = []
    var isImporting: Bool = false
    var importError: String?

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
