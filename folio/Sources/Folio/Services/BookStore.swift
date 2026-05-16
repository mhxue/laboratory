import Foundation
import SwiftData
import UIKit

@MainActor
final class BookStore {

    private let parser = EPUBParser()

    func importBook(from sourceURL: URL, context: ModelContext) throws -> Book {
        let id = UUID()
        let booksDir = booksDirectory()
        let destURL = booksDir.appendingPathComponent("\(id.uuidString).epub")
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let metadata = try parser.parse(epubURL: destURL, bookID: id)

        var coverPath: String? = nil
        if let coverData = metadata.coverImageData {
            let coverURL = coversDirectory().appendingPathComponent("\(id.uuidString).png")
            let image = UIImage(data: coverData)
            if let pngData = image?.pngData() {
                try pngData.write(to: coverURL)
                coverPath = "Covers/\(id.uuidString).png"
            }
        }

        let book = Book(
            id: id,
            title: metadata.title,
            author: metadata.author,
            filePath: "Books/\(id.uuidString).epub",
            coverPath: coverPath,
            chapterCount: metadata.chapterURLs.count
        )
        context.insert(book)
        try context.save()
        return book
    }

    func deleteBook(_ book: Book, context: ModelContext) throws {
        removeFile(relativePath: book.filePath)
        if let cp = book.coverPath { removeFile(relativePath: cp) }

        let extractDir = parser.extractionDirectory(for: book.id)
        try? FileManager.default.removeItem(at: extractDir)

        context.delete(book)
        try context.save()
    }

    func chapterURLs(for book: Book) throws -> [URL] {
        let epubURL = documentsDirectory().appendingPathComponent(book.filePath)
        // Re-extract if cache was purged
        return try parser.chapterURLs(for: book.id)
    }

    func coverImage(for book: Book) -> UIImage? {
        guard let path = book.coverPath else { return nil }
        let url = documentsDirectory().appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Directories

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
