import Foundation
import Observation
import SwiftData

/// Concrete `@Observable` implementation of `ReaderViewModeling`.
@Observable
@MainActor
final class ReaderViewModel: ReaderViewModeling {

    // MARK: - ReaderViewModeling

    private(set) var chapterURLs: [URL] = []
    var currentChapterIndex: Int = 0
    var currentPage: Int = 0
    var totalPages: Int = 1
    var scrollFraction: Double = 0
    var showChrome: Bool = true
    private(set) var isLoading: Bool = false

    /// Approximate words remaining in the book — used by the pace tracker to
    /// produce a "Xh Ym left" estimate. Caller (the view) is expected to set
    /// this once chapter sizes are known.
    var wordsRemaining: Int = 0

    /// How long the chrome stays visible before auto-hiding. Exposed for
    /// tests so they can pass a tiny interval and observe the timer.
    let chromeAutoHideDelay: TimeInterval

    /// Cancelable auto-hide task.
    @ObservationIgnored private var hideChromeTask: Task<Void, Never>?

    /// Reading-pace tracker — produces the time-left label.
    @ObservationIgnored private let paceTracker: any ReadingPaceTracking

    var overallProgress: Double {
        guard !chapterURLs.isEmpty else { return 0 }
        let chapter = Double(currentChapterIndex)
        let pageFraction = totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0
        let progress = (chapter + pageFraction) / Double(chapterURLs.count)
        return min(max(progress, 0), 1)
    }

    var timeLeftLabel: String? {
        paceTracker.formattedTimeLeft(forWords: wordsRemaining)
    }

    // MARK: - Dependencies

    private let book: Book
    private let store: any BookStoring
    private let context: ModelContext

    // MARK: - Init

    init(book: Book,
         store: any BookStoring,
         context: ModelContext,
         paceTracker: any ReadingPaceTracking = ReadingPaceTracker(fallbackWordsPerMinute: 220),
         chromeAutoHideDelay: TimeInterval = 1.5) {
        self.book = book
        self.store = store
        self.context = context
        self.paceTracker = paceTracker
        self.chromeAutoHideDelay = chromeAutoHideDelay
    }

    // MARK: - ReaderViewModeling

    func load() async {
        isLoading = true
        defer { isLoading = false }
        chapterURLs = (try? store.chapterURLs(for: book)) ?? []
        if let p = book.progress {
            currentChapterIndex = p.chapterIndex
            scrollFraction = p.scrollFraction
        }
    }

    func saveProgress() {
        if book.progress == nil {
            let p = ReadingProgress(chapterIndex: currentChapterIndex, scrollFraction: scrollFraction)
            book.progress = p
        } else {
            book.progress?.chapterIndex = currentChapterIndex
            book.progress?.scrollFraction = scrollFraction
            book.progress?.lastRead = Date()
        }
        try? context.save()
    }

    func addBookmark(note: String, kind: BookmarkKind = .important) {
        let bookmark = Bookmark(
            chapterIndex: currentChapterIndex,
            scrollFraction: scrollFraction,
            note: note,
            kind: kind
        )
        book.bookmarks.append(bookmark)
        try? context.save()
    }

    func advanceChapter() {
        guard currentChapterIndex < chapterURLs.count - 1 else { return }
        currentChapterIndex += 1
        currentPage = 0
    }

    func retreatChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        currentPage = 0
    }

    func setOverallProgress(_ fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        guard !chapterURLs.isEmpty else { return }
        let chapterFloat = clamped * Double(chapterURLs.count)
        let chapterIndex = min(Int(chapterFloat), chapterURLs.count - 1)
        let withinChapter = chapterFloat - Double(chapterIndex)
        currentChapterIndex = chapterIndex
        if totalPages > 0 {
            currentPage = min(Int((withinChapter * Double(totalPages)).rounded(.down)), max(totalPages - 1, 0))
        } else {
            currentPage = 0
        }
        scrollFraction = withinChapter
    }

    func revealChromeAndScheduleHide() {
        showChrome = true
        scheduleAutoHide()
    }

    func toggleChrome() {
        if showChrome {
            cancelChromeAutoHide()
            showChrome = false
        } else {
            revealChromeAndScheduleHide()
        }
    }

    func cancelChromeAutoHide() {
        hideChromeTask?.cancel()
        hideChromeTask = nil
    }

    /// Recording hook: bind from the view when a page actually turns to feed
    /// real samples into the pace tracker. Public so views (and tests) can
    /// drive it deterministically.
    func recordPageRead(words: Int, duration: TimeInterval) {
        paceTracker.record(words: words, over: duration)
    }

    // MARK: - Private

    private func scheduleAutoHide() {
        hideChromeTask?.cancel()
        let delay = chromeAutoHideDelay
        hideChromeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.showChrome = false
            }
        }
    }
}
