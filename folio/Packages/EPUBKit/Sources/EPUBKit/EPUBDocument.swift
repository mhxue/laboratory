import Foundation

/// The top-level parsed representation of an EPUB file.
public struct EPUBDocument: Sendable {
    public let metadata: EPUBMetadata
    /// Ordered spine items (chapters).
    public let chapters: [EPUBChapter]
    public let tableOfContents: [EPUBTOCItem]

    init(metadata: EPUBMetadata, chapters: [EPUBChapter], tableOfContents: [EPUBTOCItem]) {
        self.metadata = metadata
        self.chapters = chapters
        self.tableOfContents = tableOfContents
    }
}

/// Dublin-Core metadata extracted from the OPF package document.
public struct EPUBMetadata: Sendable {
    public let title: String
    public let author: String
    public let coverImageData: Data?
    public let language: String?

    init(title: String, author: String, coverImageData: Data? = nil, language: String? = nil) {
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.language = language
    }
}

/// A single spine item representing one chapter (HTML file) in the EPUB.
public struct EPUBChapter: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let title: String

    init(id: UUID = UUID(), url: URL, title: String) {
        self.id = id
        self.url = url
        self.title = title
    }
}

/// An entry in the EPUB navigation / table-of-contents.
public struct EPUBTOCItem: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    /// Zero-based index into `EPUBDocument.chapters`.
    public let chapterIndex: Int

    init(id: UUID = UUID(), label: String, chapterIndex: Int) {
        self.id = id
        self.label = label
        self.chapterIndex = chapterIndex
    }
}
