import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class NotesViewModel: NotesViewModeling {

    // MARK: - NotesViewModeling

    var selectedTab: NotesTab = .highlights
    var bookFilter: Book?
    var deleteError: String?

    var items: [NoteItem] {
        let entries = collectBookmarkEntries(bookFilter: bookFilter)
        return entries
            .filter { matches(tab: selectedTab, note: $0.note) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func count(for tab: NotesTab) -> Int {
        let entries = collectBookmarkEntries(bookFilter: bookFilter)
        return entries.lazy.filter { matches(tab: tab, note: $0.note) }.count
    }

    // MARK: - Dependencies

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Mutations

    func delete(_ item: NoteItem) async {
        do {
            let descriptor = FetchDescriptor<Bookmark>()
            let all = try context.fetch(descriptor)
            if let match = all.first(where: { $0.id == item.id }) {
                context.delete(match)
                try context.save()
            }
        } catch {
            deleteError = error.localizedDescription
        }
    }

    // MARK: - Private

    /// Flatten bookmarks across books into a single sequence of `NoteItem`s.
    private func collectBookmarkEntries(bookFilter: Book?) -> [NoteItem] {
        let books: [Book]
        if let book = bookFilter {
            books = [book]
        } else {
            let descriptor = FetchDescriptor<Book>()
            books = (try? context.fetch(descriptor)) ?? []
        }
        return books.flatMap { book in
            book.bookmarks.map { bm in
                NoteItem(
                    id: bm.id,
                    bookID: book.id,
                    bookTitle: book.title,
                    bookAuthor: book.author,
                    chapterIndex: bm.chapterIndex,
                    scrollFraction: bm.scrollFraction,
                    note: bm.note,
                    kind: bm.kind,
                    createdAt: bm.createdAt
                )
            }
        }
    }

    private func matches(tab: NotesTab, note: String) -> Bool {
        let hasNote = !note.isEmpty
        switch tab {
        case .highlights:   return true       // every annotation is a "highlight"
        case .notes:        return hasNote    // only ones with text
        case .bookmarks:    return !hasNote   // pure positional bookmarks (no note)
        }
    }
}
