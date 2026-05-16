import Foundation
import SwiftData
import UIKit

/// Abstraction over the on-disk book storage layer.
///
/// Conforming types manage copying EPUB files into the app's document directory,
/// persisting `Book` records via SwiftData, and providing access to extracted chapter URLs.
@MainActor
protocol BookStoring {
    func importBook(from url: URL, context: ModelContext) throws -> Book
    func deleteBook(_ book: Book, context: ModelContext) throws
    func chapterURLs(for book: Book) throws -> [URL]
    func coverImage(for book: Book) -> UIImage?
}
