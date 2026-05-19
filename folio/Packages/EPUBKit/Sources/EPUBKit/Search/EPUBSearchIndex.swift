import Foundation

/// An inverted index over one or more EPUB chapters that supports fast,
/// case-insensitive substring search.
///
/// Build once on a background thread with ``build(from:)``, then call
/// ``search(_:)`` as often as needed.
public struct EPUBSearchIndex: Sendable {

    /// A single search hit.
    public struct Match: Sendable {
        /// Stable coordinate of the match within the document.
        public var address: EPUBAddress
        /// ~60 characters of surrounding plain text for context display.
        public var snippet: String

        public init(address: EPUBAddress, snippet: String) {
            self.address = address
            self.snippet = snippet
        }
    }

    // MARK: - Storage

    /// Lowercased token → sorted list of positions.
    private let index: [String: [EPUBAddress]]

    /// Full plain text per block, keyed by (chapterIndex, blockIndex).
    private let blockTexts: [BlockKey: String]

    private struct BlockKey: Hashable, Sendable {
        let chapterIndex: Int
        let blockIndex: Int
    }

    // MARK: - Build

    /// Build an index from multiple chapters.  Call on a background thread.
    public static func build(from chapters: [(index: Int, content: EPUBContent)]) -> EPUBSearchIndex {
        var index: [String: [EPUBAddress]] = [:]
        var blockTexts: [BlockKey: String] = [:]

        for chapter in chapters {
            let chapterIdx = chapter.index
            for (blockIdx, block) in chapter.content.blocks.enumerated() {
                let text = EPUBContent.plainText(of: block)
                let key = BlockKey(chapterIndex: chapterIdx, blockIndex: blockIdx)
                blockTexts[key] = text

                // Tokenise: split on whitespace and punctuation, record each token's start offset
                let tokens = tokenise(text)
                for (token, offset) in tokens {
                    let lowered = token.lowercased()
                    let address = EPUBAddress(
                        chapterIndex: chapterIdx,
                        blockIndex: blockIdx,
                        charOffset: offset
                    )
                    index[lowered, default: []].append(address)
                }
            }
        }

        // Sort each posting list
        for key in index.keys {
            index[key]?.sort()
        }

        return EPUBSearchIndex(index: index, blockTexts: blockTexts)
    }

    // MARK: - Search

    /// Case-insensitive substring search. Returns matches sorted by address.
    ///
    /// An empty or whitespace-only query returns an empty array immediately.
    public func search(_ query: String) -> [Match] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryLower = trimmed.lowercased()

        // Collect all addresses whose block text contains the query string
        var matches: [Match] = []

        // Deduplicate: one match per (chapter, block, occurrence)
        var seen = Set<EPUBAddress>()

        for (key, text) in blockTexts {
            let lowerText = text.lowercased()
            guard lowerText.contains(queryLower) else { continue }

            // Find all occurrences
            var searchRange = lowerText.startIndex..<lowerText.endIndex
            while let range = lowerText.range(of: queryLower, range: searchRange) {
                let charOffset = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
                let address = EPUBAddress(
                    chapterIndex: key.chapterIndex,
                    blockIndex: key.blockIndex,
                    charOffset: charOffset
                )
                if !seen.contains(address) {
                    seen.insert(address)
                    let snippet = makeSnippet(from: text, at: charOffset, queryLength: trimmed.count)
                    matches.append(Match(address: address, snippet: snippet))
                }
                // Advance search past this match
                searchRange = range.upperBound..<lowerText.endIndex
            }
        }

        matches.sort { $0.address < $1.address }
        return matches
    }

    // MARK: - Private helpers

    private init(index: [String: [EPUBAddress]], blockTexts: [BlockKey: String]) {
        self.index = index
        self.blockTexts = blockTexts
    }

    /// Split `text` into (token, startOffset) pairs. Splits on whitespace and basic punctuation.
    private static func tokenise(_ text: String) -> [(token: String, offset: Int)] {
        var results: [(String, Int)] = []
        var currentToken: [Character] = []
        var tokenStart = 0
        var currentOffset = 0

        let separators: Set<Character> = [" ", "\n", "\r", "\t", ".", ",", "!", "?", ";", ":", "\"", "'", "(", ")", "[", "]", "-", "—", "/", "\\"]

        for ch in text {
            if separators.contains(ch) {
                if !currentToken.isEmpty {
                    results.append((String(currentToken), tokenStart))
                    currentToken = []
                }
                tokenStart = currentOffset + 1
            } else {
                currentToken.append(ch)
            }
            currentOffset += 1
        }
        if !currentToken.isEmpty {
            results.append((String(currentToken), tokenStart))
        }
        return results
    }

    /// Generate a ~60-char snippet centred around `offset`.
    private func makeSnippet(from text: String, at offset: Int, queryLength: Int) -> String {
        let snippetRadius = 30
        let startIndex = max(0, offset - snippetRadius)
        let endIndex = min(text.count, offset + queryLength + snippetRadius)

        let strStart = text.index(text.startIndex, offsetBy: startIndex)
        let strEnd = text.index(text.startIndex, offsetBy: endIndex)

        var snippet = String(text[strStart..<strEnd])
        if startIndex > 0 { snippet = "…" + snippet }
        if endIndex < text.count { snippet = snippet + "…" }
        return snippet
    }
}
