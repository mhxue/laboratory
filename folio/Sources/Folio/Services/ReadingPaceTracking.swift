import Foundation

/// Computes "X min left" estimates from rolling-average reading pace samples.
///
/// The reader feeds it `record(words:over:)` per page turn; consumers ask
/// `minutesLeft(forWords:)` to format a "4h 12m left in book" string.
///
/// Pure value/calc layer — fully unit-testable. `@MainActor` because the
/// only consumer is `ReaderViewModel` (also `@MainActor`), and pinning the
/// protocol avoids a Sendable parade for the stored implementation.
@MainActor
protocol ReadingPaceTracking: AnyObject {
    /// Current rolling-average pace, in words per minute. `nil` until a
    /// minimum number of samples has been collected, so callers can suppress
    /// noisy "1h left" estimates from a single page turn.
    var wordsPerMinute: Double? { get }

    /// The number of samples that have been recorded since init.
    var sampleCount: Int { get }

    /// Record a single reading observation. Negative or zero `duration`
    /// values are dropped to avoid divide-by-zero pollution.
    func record(words: Int, over duration: TimeInterval)

    /// Estimated minutes left to read `words` more words at the current pace,
    /// or `nil` if we don't yet have a stable pace estimate.
    func minutesLeft(forWords words: Int) -> Int?

    /// Reset all samples — used when switching books, where carrying pace
    /// across drastically different content (novel ↔ technical) is misleading.
    func reset()
}

/// Concrete `ReadingPaceTracking` implementation backed by a fixed-size
/// rolling window of pace samples.
@MainActor
final class ReadingPaceTracker: ReadingPaceTracking {

    /// Minimum number of samples we require before producing an estimate.
    /// Below this we return `nil` so the UI can fall back to "—".
    let minSampleCount: Int

    /// Maximum samples retained. Older samples are dropped FIFO — keeps the
    /// estimate responsive to changes in pace (e.g. user starts reading more
    /// slowly through a dense chapter).
    let windowSize: Int

    /// Default to 200 wpm (a comfortable adult reading pace) when no samples
    /// have been recorded yet. `nil` disables the fallback so callers see
    /// `wordsPerMinute == nil` until real data arrives.
    let fallbackWordsPerMinute: Double?

    private var samples: [(words: Int, duration: TimeInterval)] = []

    init(minSampleCount: Int = 3,
         windowSize: Int = 30,
         fallbackWordsPerMinute: Double? = nil) {
        self.minSampleCount = minSampleCount
        self.windowSize = windowSize
        self.fallbackWordsPerMinute = fallbackWordsPerMinute
    }

    var sampleCount: Int { samples.count }

    var wordsPerMinute: Double? {
        guard !samples.isEmpty else { return fallbackWordsPerMinute }
        if samples.count < minSampleCount { return fallbackWordsPerMinute }

        let totalWords = samples.reduce(0) { $0 + $1.words }
        let totalSeconds = samples.reduce(0.0) { $0 + $1.duration }
        guard totalSeconds > 0 else { return fallbackWordsPerMinute }
        return Double(totalWords) / totalSeconds * 60.0
    }

    func record(words: Int, over duration: TimeInterval) {
        guard duration > 0, words > 0 else { return }
        samples.append((words, duration))
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }
    }

    func minutesLeft(forWords words: Int) -> Int? {
        guard let wpm = wordsPerMinute, wpm > 0, words >= 0 else { return nil }
        let minutes = Double(words) / wpm
        return max(0, Int(minutes.rounded()))
    }

    func reset() {
        samples.removeAll()
    }
}

// MARK: - Convenience formatters

extension ReadingPaceTracking {
    /// Formats `minutesLeft(forWords:)` into the design's preferred
    /// "Xh Ym left" / "Xm left" style. Returns `nil` if we have no estimate.
    func formattedTimeLeft(forWords words: Int) -> String? {
        guard let minutes = minutesLeft(forWords: words) else { return nil }
        if minutes < 1 { return "<1m left" }
        if minutes < 60 { return "\(minutes)m left" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h left" : "\(hours)h \(mins)m left"
    }
}
