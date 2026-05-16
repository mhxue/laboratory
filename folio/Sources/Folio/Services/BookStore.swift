import Foundation
import SwiftData
import UIKit
import EPUBKit

/// Concrete `@MainActor` implementation of `BookStoring`.
///
/// Copies EPUB files into `Documents/Books/`, extracts them to
/// `Caches/Extracted/<id>/`, and persists `Book` records via SwiftData.
/// Cover images are saved as PNGs under `Documents/Covers/`.
@MainActor
final class BookStore: BookStoring {

    private let parser: any EPUBParsing

    init(parser: any EPUBParsing = EPUBParser()) {
        self.parser = parser
    }

    // MARK: - BookStoring

    func importBook(from sourceURL: URL, context: ModelContext) throws -> Book {
        let id = UUID()
        let booksDir = booksDirectory()
        let destURL = booksDir.appendingPathComponent("\(id.uuidString).epub")
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let extractDir = extractionDirectory(for: id)
        let document = try parser.parse(epubAt: destURL, extractingTo: extractDir)

        var coverPath: String?
        if let coverData = document.metadata.coverImageData {
            let coverURL = coversDirectory().appendingPathComponent("\(id.uuidString).png")
            let image = UIImage(data: coverData)
            if let pngData = image?.pngData() {
                try pngData.write(to: coverURL)
                coverPath = "Covers/\(id.uuidString).png"
            }
        }

        let book = Book(
            id: id,
            title: document.metadata.title,
            author: document.metadata.author,
            filePath: "Books/\(id.uuidString).epub",
            coverPath: coverPath,
            chapterCount: document.chapters.count
        )
        context.insert(book)
        try context.save()
        return book
    }

    func deleteBook(_ book: Book, context: ModelContext) throws {
        removeFile(relativePath: book.filePath)
        if let cp = book.coverPath { removeFile(relativePath: cp) }
        let extractDir = extractionDirectory(for: book.id)
        try? FileManager.default.removeItem(at: extractDir)
        context.delete(book)
        try context.save()
    }

    func chapterURLs(for book: Book) throws -> [URL] {
        let destURL = documentsDirectory().appendingPathComponent(book.filePath)
        let extractDir = extractionDirectory(for: book.id)
        let document = try parser.parse(epubAt: destURL, extractingTo: extractDir)
        return document.chapters.map(\.url)
    }

    func coverImage(for book: Book) -> UIImage? {
        guard let path = book.coverPath else { return nil }
        let url = documentsDirectory().appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Directories

    func extractionDirectory(for bookID: UUID) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Extracted/\(bookID.uuidString)", isDirectory: true)
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func booksDirectory() -> URL {
        let url = documentsDirectory().appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func coversDirectory() -> URL {
        let url = documentsDirectory().appendingPathComponent("Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func removeFile(relativePath: String) {
        let url = documentsDirectory().appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}
