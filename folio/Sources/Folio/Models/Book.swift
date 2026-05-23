import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    var filePath: String
    var coverPath: String?
    var chapterCount: Int
    var addedDate: Date
    @Relationship(deleteRule: .cascade) var progress: ReadingProgress?
    @Relationship(deleteRule: .cascade) var bookmarks: [Bookmark]

    init(id: UUID = UUID(), title: String, author: String, filePath: String, coverPath: String? = nil, chapterCount: Int) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.coverPath = coverPath
        self.chapterCount = chapterCount
        self.addedDate = Date()
        self.bookmarks = []
    }

    var progressFraction: Double {
        guard let p = progress, chapterCount > 0 else { return 0 }
        let chapterFraction = Double(p.chapterIndex) / Double(chapterCount)
        let withinChapter = p.scrollFraction / Double(chapterCount)
        return min(chapterFraction + withinChapter, 1.0)
    }

    /// `true` when the reader has reached the very last position. Treats a
    /// book without a `progress` row as unread.
    var isFinished: Bool {
        progressFraction >= 1.0
    }

    /// `true` when the reader has any progress but hasn't finished. Mirrors
    /// what the Library's "Reading" filter expects.
    var isInProgress: Bool {
        guard progress != nil else { return false }
        return progressFraction > 0 && progressFraction < 1
    }

    /// `true` when no `ReadingProgress` row exists at all.
    var isUnread: Bool {
        progress == nil
    }
}

@Model
final class ReadingProgress {
    var chapterIndex: Int
    var scrollFraction: Double
    var lastRead: Date

    init(chapterIndex: Int = 0, scrollFraction: Double = 0) {
        self.chapterIndex = chapterIndex
        self.scrollFraction = scrollFraction
        self.lastRead = Date()
    }
}

/// Intent behind a highlight / bookmark — drives the colour bar in the Notes UI.
///
/// `important` (amber) is the default for the "tap to bookmark" gesture. The
/// other two kinds are surfaced when the user explicitly long-presses or picks
/// from the highlight menu.
enum BookmarkKind: String, CaseIterable, Codable, Sendable {
    case important     // amber — "this matters"
    case connection    // green — "this links to X"
    case lookup        // yellow — "come back to this"

    var displayName: String {
        switch self {
        case .important:    return "Important"
        case .connection:   return "Connection"
        case .lookup:       return "Look up later"
        }
    }
}

@Model
final class Bookmark {
    var id: UUID
    var chapterIndex: Int
    var scrollFraction: Double
    var note: String
    var createdAt: Date

    /// Raw storage for `BookmarkKind`. Optional + computed wrapper so the
    /// existing SwiftData store can migrate without a heavy migration step:
    /// old rows have no value, the getter falls back to `.important`.
    var kindRaw: String?

    init(chapterIndex: Int,
         scrollFraction: Double,
         note: String = "",
         kind: BookmarkKind = .important) {
        self.id = UUID()
        self.chapterIndex = chapterIndex
        self.scrollFraction = scrollFraction
        self.note = note
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
    }

    /// Type-safe accessor for the bookmark's intent. Defaults to `.important`
    /// when the underlying SwiftData row predates the field.
    var kind: BookmarkKind {
        get { kindRaw.flatMap(BookmarkKind.init(rawValue:)) ?? .important }
        set { kindRaw = newValue.rawValue }
    }
}
