import Foundation

/// ViewModel protocol for the reader screen.
///
/// Views should be generic over this protocol so that mock implementations
/// can be substituted in tests and Xcode Previews.
@MainActor
protocol ReaderViewModeling: AnyObject, Observable {
    var chapterURLs: [URL] { get }
    var currentChapterIndex: Int { get set }
    var scrollFraction: Double { get set }
    var showChrome: Bool { get set }
    var isLoading: Bool { get }
    func load() async
    func saveProgress()
    func addBookmark(note: String)
}
