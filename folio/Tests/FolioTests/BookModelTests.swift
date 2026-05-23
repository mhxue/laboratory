import XCTest
import SwiftData
@testable import Folio

@MainActor
final class BookModelTests: XCTestCase {

    // MARK: - progressFraction

    func test_progressFraction_isZero_whenNoProgress() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 10)
        XCTAssertEqual(book.progressFraction, 0, accuracy: 1e-6)
    }

    func test_progressFraction_atChapterStart_isChapterIndexOverCount() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0)
        XCTAssertEqual(book.progressFraction, 0.5, accuracy: 1e-6)
    }

    func test_progressFraction_midChapter_combinesIndexAndScroll() {
        // chapter 1 of 4 at 50% within chapter = 1/4 + 0.5/4 = 0.375
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 1, scrollFraction: 0.5)
        XCTAssertEqual(book.progressFraction, 0.375, accuracy: 1e-6)
    }

    func test_progressFraction_isClampedTo1() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 2)
        book.progress = ReadingProgress(chapterIndex: 5, scrollFraction: 0.9)
        XCTAssertEqual(book.progressFraction, 1.0, accuracy: 1e-6)
    }

    func test_progressFraction_isZero_whenChapterCountZero() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 0)
        book.progress = ReadingProgress(chapterIndex: 1, scrollFraction: 0.5)
        XCTAssertEqual(book.progressFraction, 0)
    }

    // MARK: - reading-state computeds

    func test_isUnread_trueWhenNoProgress() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 4)
        XCTAssertTrue(book.isUnread)
        XCTAssertFalse(book.isInProgress)
        XCTAssertFalse(book.isFinished)
    }

    func test_isInProgress_trueWhenSomeProgressButNotFinished() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 1, scrollFraction: 0.5)
        XCTAssertFalse(book.isUnread)
        XCTAssertTrue(book.isInProgress)
        XCTAssertFalse(book.isFinished)
    }

    func test_isFinished_trueAtFullProgress() {
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 2)
        book.progress = ReadingProgress(chapterIndex: 2, scrollFraction: 0)
        XCTAssertFalse(book.isInProgress)
        XCTAssertTrue(book.isFinished)
    }

    func test_isInProgress_falseWhenChapterIndexNonZero_butScrollZero() {
        // Edge: a fresh progress row at chapter 0, scroll 0 should not count as "in progress".
        let book = Book(title: "T", author: "A", filePath: "p", chapterCount: 4)
        book.progress = ReadingProgress(chapterIndex: 0, scrollFraction: 0)
        XCTAssertFalse(book.isInProgress)
        XCTAssertFalse(book.isFinished)
    }

    // MARK: - Bookmark.kind

    func test_bookmark_defaultKind_isImportant() {
        let bm = Bookmark(chapterIndex: 0, scrollFraction: 0)
        XCTAssertEqual(bm.kind, .important)
    }

    func test_bookmark_kind_storedRoundtrip() {
        let bm = Bookmark(chapterIndex: 0, scrollFraction: 0, kind: .connection)
        XCTAssertEqual(bm.kind, .connection)
        bm.kind = .lookup
        XCTAssertEqual(bm.kind, .lookup)
        XCTAssertEqual(bm.kindRaw, "lookup")
    }

    func test_bookmark_kind_fallsBackToImportant_whenRawIsNil() {
        // Simulates a row migrated from the old schema (no kindRaw).
        let bm = Bookmark(chapterIndex: 0, scrollFraction: 0)
        bm.kindRaw = nil
        XCTAssertEqual(bm.kind, .important)
    }

    func test_bookmark_kind_fallsBackToImportant_whenRawIsUnknown() {
        let bm = Bookmark(chapterIndex: 0, scrollFraction: 0)
        bm.kindRaw = "blahblah"
        XCTAssertEqual(bm.kind, .important)
    }

    func test_bookmark_kind_allCases_coverThreeIntents() {
        XCTAssertEqual(Set(BookmarkKind.allCases), [.important, .connection, .lookup])
    }
}
