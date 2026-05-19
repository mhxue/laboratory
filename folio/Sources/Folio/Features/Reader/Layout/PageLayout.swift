import Foundation
import EPUBKit

/// The result of paginating a chapter's blocks into screen-sized pages.
struct PageLayout {

    // MARK: - Page descriptor

    struct Page {
        /// Which chapter this page belongs to.
        var chapterIndex: Int
        /// Position of this page within the chapter (0-based).
        var pageIndex: Int
        /// Indices into the chapter's `[EPUBBlock]` array.
        var blockIndices: [Int]
        /// Address of the first block on this page.
        var address: EPUBAddress
    }

    // MARK: - Computed result

    let pages: [Page]

    // MARK: - Computation

    /// Compute page layout synchronously — call from a background `Task`.
    ///
    /// - Parameters:
    ///   - blocks: All blocks for the chapter.
    ///   - chapterIndex: Index of this chapter in the book spine.
    ///   - pageHeight: Available height (safe-area-adjusted).
    ///   - measurer: Block measurer pre-configured with the page width and stylesheet.
    static func compute(
        blocks: [EPUBBlock],
        chapterIndex: Int,
        pageHeight: CGFloat,
        measurer: BlockMeasurer
    ) -> PageLayout {
        guard !blocks.isEmpty, pageHeight > 0 else {
            return PageLayout(pages: [])
        }

        var pages: [Page] = []
        var currentBlockIndices: [Int] = []
        var accumulatedHeight: CGFloat = 0
        var pageIndex = 0

        for (blockIdx, block) in blocks.enumerated() {
            let blockHeight = measurer.height(of: block)

            // Would adding this block overflow the current page?
            let wouldOverflow = accumulatedHeight + blockHeight > pageHeight

            if wouldOverflow && !currentBlockIndices.isEmpty {
                // Flush the current page
                let firstIdx = currentBlockIndices[0]
                let page = Page(
                    chapterIndex: chapterIndex,
                    pageIndex: pageIndex,
                    blockIndices: currentBlockIndices,
                    address: EPUBAddress(chapterIndex: chapterIndex, blockIndex: firstIdx, charOffset: 0)
                )
                pages.append(page)
                pageIndex += 1

                // Start a fresh page with this block
                currentBlockIndices = [blockIdx]
                accumulatedHeight = blockHeight
            } else {
                currentBlockIndices.append(blockIdx)
                accumulatedHeight += blockHeight
            }
        }

        // Flush any remaining blocks as the last page
        if !currentBlockIndices.isEmpty {
            let firstIdx = currentBlockIndices[0]
            let page = Page(
                chapterIndex: chapterIndex,
                pageIndex: pageIndex,
                blockIndices: currentBlockIndices,
                address: EPUBAddress(chapterIndex: chapterIndex, blockIndex: firstIdx, charOffset: 0)
            )
            pages.append(page)
        }

        // Ensure at least one page even if empty
        if pages.isEmpty {
            pages.append(Page(
                chapterIndex: chapterIndex,
                pageIndex: 0,
                blockIndices: [],
                address: .zero
            ))
        }

        return PageLayout(pages: pages)
    }
}
