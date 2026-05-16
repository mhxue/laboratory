import Foundation
import SwiftData

/// ViewModel protocol for the library screen.
///
/// Views should be generic over this protocol so that mock implementations
/// can be substituted in tests and Xcode Previews.
@MainActor
protocol LibraryViewModeling: AnyObject, Observable {
    var books: [Book] { get }
    var isImporting: Bool { get set }
    var importError: String? { get set }
    func importBook(from url: URL) async
    func deleteBook(_ book: Book) async
}
