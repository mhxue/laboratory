import Foundation
import SwiftData

/// Top-level tab in the Notes screen.
enum NotesTab: String, CaseIterable, Sendable {
    case highlights
    case notes
    case bookmarks

    var displayName: String {
        switch self {
        case .highlights:   return "Highlights"
        case .notes:        return "Notes"
        case .bookmarks:    return "Bookmarks"
        }
    }
}

/// One row displayed in the Notes list — a flat representation that hides
/// SwiftData relationships from the view.
struct NoteItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let bookTitle: String
    let bookAuthor: String
    let chapterIndex: Int
    let scrollFraction: Double
    let note: String
    let kind: BookmarkKind
    let createdAt: Date
}

/// ViewModel protocol for the Notes / Highlights / Bookmarks screen.
@MainActor
protocol NotesViewModeling: AnyObject, Observable {
    var selectedTab: NotesTab { get set }

    /// Optional book filter — `nil` shows annotations from every book.
    var bookFilter: Book? { get set }

    /// All annotations (already filtered by `selectedTab` and `bookFilter`),
    /// sorted newest-first.
    var items: [NoteItem] { get }

    /// Count for each tab — drives the chip pill counters.
    func count(for tab: NotesTab) -> Int

    /// Remove a bookmark by id. Surfaces an error string on failure.
    func delete(_ item: NoteItem) async
    var deleteError: String? { get set }
}
