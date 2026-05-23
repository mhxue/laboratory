import Foundation

/// One row in the chapter list shown on the Book Detail screen.
struct ChapterEntry: Identifiable, Equatable, Sendable {
    let id: Int             // == chapterIndex
    let title: String       // "Chapter \(idx+1)" until we wire TOC labels
    let estimatedMinutes: Int?
    var isCurrent: Bool
    var isRead: Bool
}

/// ViewModel protocol for the Book Detail / ownership view.
@MainActor
protocol BookDetailViewModeling: AnyObject, Observable {
    var book: Book { get }

    /// Pre-formatted file size — "2.4 MB" / "812 KB".
    var fileSizeFormatted: String { get }

    /// `true` when the book's file is present on disk. Surfaces "missing"
    /// states defensively (e.g. user deleted the document folder).
    var isStoredLocally: Bool { get }

    /// All chapters, in order. `isCurrent` flags the in-progress chapter.
    var chapters: [ChapterEntry] { get }

    /// Local file URL for AirDrop / share-sheet / "Open in" actions. `nil`
    /// when the file can't be located.
    func exportURL() -> URL?
}
