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

@Model
final class Bookmark {
    var id: UUID
    var chapterIndex: Int
    var scrollFraction: Double
    var note: String
    var createdAt: Date

    init(chapterIndex: Int, scrollFraction: Double, note: String = "") {
        self.id = UUID()
        self.chapterIndex = chapterIndex
        self.scrollFraction = scrollFraction
        self.note = note
        self.createdAt = Date()
    }
}
