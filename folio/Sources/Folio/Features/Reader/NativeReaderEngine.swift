import Foundation
import SwiftUI
import EPUBKit

/// Parses an XHTML chapter file, measures blocks, and paginates them
/// into ``PageLayout/Page`` values for ``EPUBPageView``.
///
/// All mutations happen on `@MainActor`; the heavy work runs on a
/// detached background task and the result is published back on main.
@MainActor
@Observable
final class NativeReaderEngine {

    // MARK: - Published state

    private(set) var pages: [PageLayout.Page] = []
    private(set) var blocks: [EPUBBlock] = []
    private(set) var isReady: Bool = false
    /// `true` while a chapter load is in flight (for adjacent-chapter prefetch awareness).
    /// The turn view coordinator can show a spinner when crossing chapter boundaries.
    private(set) var isLoadingAdjacentChapter: Bool = false

    // MARK: - Private

    private let parser: any EPUBContentParsing
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(parser: any EPUBContentParsing = XHTMLContentParser()) {
        self.parser = parser
    }

    // MARK: - Public API

    /// Parse and paginate a chapter XHTML file for the given page size.
    ///
    /// - Parameters:
    ///   - isAdjacentPrefetch: Pass `true` when loading a neighbouring chapter so
    ///     callers (e.g. `BookPageTurnView`'s coordinator) can observe
    ///     `isLoadingAdjacentChapter` and show a spinner at the chapter boundary.
    ///     Defaults to `false` so all existing call-sites are unaffected.
    func load(chapterURL: URL, stylesheet: EPUBStylesheet, pageSize: CGSize, deviceClass: DeviceClass = .compact, isAdjacentPrefetch: Bool = false) {
        isReady = false
        pages = []
        blocks = []
        isLoadingAdjacentChapter = isAdjacentPrefetch
        loadTask?.cancel()
        let capturedParser = parser  // capture before leaving @MainActor context
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let content = try capturedParser.parse(xhtmlAt: chapterURL)
                let measurer = BlockMeasurer(pageWidth: pageSize.width, stylesheet: stylesheet, deviceClass: deviceClass)
                let layout = PageLayout.compute(
                    blocks: content.blocks,
                    chapterIndex: 0,
                    pageHeight: pageSize.height,
                    measurer: measurer
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.blocks = content.blocks
                    self.pages = layout.pages
                    self.isReady = true
                    self.isLoadingAdjacentChapter = false
                }
            } catch {
                // Non-fatal: leave isReady = false, caller shows fallback.
            }
        }
    }
}
