import Foundation
import SwiftData

/// Reading-state filter applied to the library grid.
///
/// `all` keeps the current sort order (most recently added first). The other
/// three derive from `Book.isInProgress` / `.isFinished` / `.isUnread`.
enum LibraryFilter: String, CaseIterable, Sendable {
    case all
    case reading
    case finished
    case unread

    var displayName: String {
        switch self {
        case .all:      return "All"
        case .reading:  return "Reading"
        case .finished: return "Finished"
        case .unread:   return "Unread"
        }
    }
}

/// ViewModel protocol for the library screen.
///
/// Views should be generic over this protocol so that mock implementations
/// can be substituted in tests and Xcode Previews.
@MainActor
protocol LibraryViewModeling: AnyObject, Observable {
    var books: [Book] { get }
    var filter: LibraryFilter { get set }
    var isImporting: Bool { get set }
    var importError: String? { get set }

    /// Books filtered by `filter`, sorted by `addedDate` descending.
    var filteredBooks: [Book] { get }

    /// The most-recently-read in-progress book, surfaced in the "Continue
    /// reading" hero card. `nil` when nothing is in progress.
    var continueReading: Book? { get }

    /// Total counts by filter — used to populate the filter pill chips.
    func count(for filter: LibraryFilter) -> Int

    func importBook(from url: URL) async
    func deleteBook(_ book: Book) async
}
