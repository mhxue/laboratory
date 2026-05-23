import XCTest
@testable import Folio

@MainActor
final class ReadingPaceTrackerTests: XCTestCase {

    // MARK: - Default state

    func test_initial_wpm_isNil_whenNoFallback() {
        let tracker = ReadingPaceTracker()
        XCTAssertNil(tracker.wordsPerMinute)
        XCTAssertEqual(tracker.sampleCount, 0)
    }

    func test_initial_wpm_isFallback_whenProvided() {
        let tracker = ReadingPaceTracker(fallbackWordsPerMinute: 220)
        XCTAssertEqual(tracker.wordsPerMinute, 220)
    }

    // MARK: - record + wpm

    func test_recording_belowMinSamples_returnsFallback() {
        let tracker = ReadingPaceTracker(minSampleCount: 3, fallbackWordsPerMinute: 200)
        tracker.record(words: 200, over: 60)  // 200 wpm sample
        // Still below minSampleCount of 3 — should keep returning the fallback.
        XCTAssertEqual(tracker.wordsPerMinute, 200)
        XCTAssertEqual(tracker.sampleCount, 1)
    }

    func test_recording_aboveMinSamples_returnsRollingAverage() {
        let tracker = ReadingPaceTracker(minSampleCount: 2)
        tracker.record(words: 200, over: 60)  // 200 wpm
        tracker.record(words: 400, over: 60)  // 400 wpm
        // Aggregate: (200+400) words in 120s = 5 wps = 300 wpm
        XCTAssertEqual(tracker.wordsPerMinute ?? 0, 300, accuracy: 0.5)
    }

    func test_recording_dropsNonPositiveDuration() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 0)
        tracker.record(words: 200, over: -10)
        XCTAssertEqual(tracker.sampleCount, 0)
        XCTAssertNil(tracker.wordsPerMinute)
    }

    func test_recording_dropsZeroWords() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 0, over: 30)
        XCTAssertEqual(tracker.sampleCount, 0)
    }

    func test_recording_evictsOldestBeyondWindow() {
        let tracker = ReadingPaceTracker(minSampleCount: 1, windowSize: 2)
        tracker.record(words: 100, over: 60)  // 100 wpm — will be evicted
        tracker.record(words: 300, over: 60)  // 300 wpm
        tracker.record(words: 300, over: 60)  // 300 wpm
        XCTAssertEqual(tracker.sampleCount, 2)
        // Only the two 300 wpm samples remain
        XCTAssertEqual(tracker.wordsPerMinute ?? 0, 300, accuracy: 0.5)
    }

    // MARK: - minutesLeft

    func test_minutesLeft_isNil_whenNoPaceYet() {
        let tracker = ReadingPaceTracker(minSampleCount: 2)
        tracker.record(words: 100, over: 60)  // only one sample
        XCTAssertNil(tracker.minutesLeft(forWords: 5000))
    }

    func test_minutesLeft_atKnownPace() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)  // 200 wpm
        // 5000 words / 200 wpm = 25 min
        XCTAssertEqual(tracker.minutesLeft(forWords: 5000), 25)
    }

    func test_minutesLeft_isZero_forZeroWords() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        XCTAssertEqual(tracker.minutesLeft(forWords: 0), 0)
    }

    func test_minutesLeft_isNil_forNegativeWords() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        XCTAssertNil(tracker.minutesLeft(forWords: -10))
    }

    // MARK: - formattedTimeLeft

    func test_formattedTimeLeft_lessThanAMinute() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        // 50 words at 200 wpm = 0.25 min → rounds to 0 → "<1m left"
        XCTAssertEqual(tracker.formattedTimeLeft(forWords: 50), "<1m left")
    }

    func test_formattedTimeLeft_minutesOnly() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        XCTAssertEqual(tracker.formattedTimeLeft(forWords: 1000), "5m left")
    }

    func test_formattedTimeLeft_hoursAndMinutes() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        // 14400 words / 200 wpm = 72 min = 1h 12m
        XCTAssertEqual(tracker.formattedTimeLeft(forWords: 14400), "1h 12m left")
    }

    func test_formattedTimeLeft_wholeHoursDropMinutes() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        // 24000 words / 200 wpm = 120 min = 2h 0m → "2h left"
        XCTAssertEqual(tracker.formattedTimeLeft(forWords: 24000), "2h left")
    }

    func test_formattedTimeLeft_isNil_withoutPace() {
        let tracker = ReadingPaceTracker()
        XCTAssertNil(tracker.formattedTimeLeft(forWords: 1000))
    }

    // MARK: - reset

    func test_reset_clearsSamples() {
        let tracker = ReadingPaceTracker(minSampleCount: 1)
        tracker.record(words: 200, over: 60)
        tracker.record(words: 200, over: 60)
        XCTAssertEqual(tracker.sampleCount, 2)
        tracker.reset()
        XCTAssertEqual(tracker.sampleCount, 0)
        XCTAssertNil(tracker.wordsPerMinute)
    }
}
