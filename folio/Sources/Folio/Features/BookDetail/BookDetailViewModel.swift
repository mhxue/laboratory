import Foundation
import Observation

/// Lightweight indirection over the bits of `FileManager` the detail view
/// needs. Allows unit tests to provide an in-memory file system.
protocol BookFileLocating: Sendable {
    /// Absolute URL for a book's file given a relative `filePath`. Returns
    /// `nil` if the path can't be resolved.
    func absoluteURL(for relativePath: String) -> URL?

    /// File size in bytes, or `nil` if missing.
    func fileSize(at url: URL) -> Int64?
}

/// Default implementation backed by the user's Documents directory.
struct DocumentsFileLocator: BookFileLocating {
    func absoluteURL(for relativePath: String) -> URL? {
        guard let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent(relativePath)
    }

    func fileSize(at url: URL) -> Int64? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value
    }
}

@Observable
@MainActor
final class BookDetailViewModel: BookDetailViewModeling {

    // MARK: - BookDetailViewModeling

    let book: Book

    var fileSizeFormatted: String {
        guard let url = locator.absoluteURL(for: book.filePath),
              let bytes = locator.fileSize(at: url) else { return "—" }
        return Self.byteFormatter.string(fromByteCount: bytes)
    }

    var isStoredLocally: Bool {
        guard let url = locator.absoluteURL(for: book.filePath) else { return false }
        return locator.fileSize(at: url) != nil
    }

    var chapters: [ChapterEntry] {
        guard book.chapterCount > 0 else { return [] }
        let currentIndex = book.progress?.chapterIndex ?? -1
        return (0..<book.chapterCount).map { idx in
            ChapterEntry(
                id: idx,
                title: "Chapter \(idx + 1)",
                estimatedMinutes: nil,
                isCurrent: idx == currentIndex,
                isRead: idx < currentIndex
            )
        }
    }

    // MARK: - Dependencies

    private let locator: any BookFileLocating

    // MARK: - Init

    init(book: Book, locator: any BookFileLocating = DocumentsFileLocator()) {
        self.book = book
        self.locator = locator
    }

    // MARK: - Export

    func exportURL() -> URL? {
        guard let url = locator.absoluteURL(for: book.filePath),
              locator.fileSize(at: url) != nil else { return nil }
        return url
    }

    // MARK: - Formatters

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()
}
