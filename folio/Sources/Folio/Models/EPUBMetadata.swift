import Foundation

struct EPUBMetadata {
    var title: String
    var author: String
    var coverImageData: Data?
    var chapterURLs: [URL]
    var tableOfContents: [TOCItem]
}

struct TOCItem: Identifiable {
    let id = UUID()
    var label: String
    var chapterIndex: Int
}
