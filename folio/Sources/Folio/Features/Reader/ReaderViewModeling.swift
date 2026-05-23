import Foundation

/// ViewModel protocol for the reader screen.
///
/// Views should be generic over this protocol so that mock implementations
/// can be substituted in tests and Xcode Previews.
@MainActor
protocol ReaderViewModeling: AnyObject, Observable {
    var chapterURLs: [URL] { get }
    var currentChapterIndex: Int { get set }
    var currentPage: Int { get set }
    var totalPages: Int { get set }
    var scrollFraction: Double { get set }

    /// `true` while the user has the top/bottom overlays visible. Starts
    /// `true` then auto-hides after `chromeAutoHideDelay` (see `startChromeAutoHide`).
    var showChrome: Bool { get set }

    var isLoading: Bool { get }

    /// Overall progress (0…1) across the whole book — derived from the
    /// current chapter index, total chapter count and page-within-chapter.
    /// Lets the scrubber bind to a single value across chapter boundaries.
    var overallProgress: Double { get }

    /// User-facing "X% · Yh Zm left" pair for the bottom chrome label.
    /// `nil` when there's no pace estimate yet.
    var timeLeftLabel: String? { get }

    func load() async
    func saveProgress()
    func addBookmark(note: String, kind: BookmarkKind)
    func advanceChapter()
    func retreatChapter()

    /// Jump to an arbitrary point in the book by overall-progress fraction.
    /// Used by the bottom-chrome scrubber.
    func setOverallProgress(_ fraction: Double)

    /// Reveal the chrome and schedule auto-hide.
    func revealChromeAndScheduleHide()

    /// Toggle chrome immediately (used by center-tap).
    func toggleChrome()

    /// Cancel any pending auto-hide (e.g. when the user starts interacting
    /// with the scrubber).
    func cancelChromeAutoHide()
}
