import Foundation

/// A stable, serialisable coordinate into an EPUB document.
///
/// Identifies a specific character position within a chapter by:
/// - which chapter (``chapterIndex``)
/// - which block within that chapter (``blockIndex``)
/// - the byte offset into the block's plain text (``charOffset``)
public struct EPUBAddress: Hashable, Codable, Sendable, Comparable {
    public var chapterIndex: Int
    public var blockIndex: Int
    /// Byte offset within the block's plain text (UTF-16 code unit index).
    public var charOffset: Int

    public static let zero = EPUBAddress(chapterIndex: 0, blockIndex: 0, charOffset: 0)

    public init(chapterIndex: Int, blockIndex: Int, charOffset: Int) {
        self.chapterIndex = chapterIndex
        self.blockIndex = blockIndex
        self.charOffset = charOffset
    }

    public static func < (lhs: EPUBAddress, rhs: EPUBAddress) -> Bool {
        if lhs.chapterIndex != rhs.chapterIndex { return lhs.chapterIndex < rhs.chapterIndex }
        if lhs.blockIndex != rhs.blockIndex { return lhs.blockIndex < rhs.blockIndex }
        return lhs.charOffset < rhs.charOffset
    }
}

// MARK: - EPUBContent plain-text helpers

extension EPUBContent {
    /// Extracts the plain text of a single block (no HTML, no tags).
    /// Nested blocks (blockquote) are separated by newlines.
    public static func plainText(of block: EPUBBlock) -> String {
        switch block {
        // ── Existing ────────────────────────────────────────────────────────
        case .paragraph(let inlines, _):
            return plainText(of: inlines)
        case .heading(_, let inlines):
            return plainText(of: inlines)
        case .blockquote(let blocks):
            return blocks.map { plainText(of: $0) }.joined(separator: "\n")
        case .image(_, let alt):
            return alt ?? ""
        case .divider:
            return ""

        // ── Lists ────────────────────────────────────────────────────────────
        case .unorderedList(let items):
            return items.map { item in
                var parts = [plainText(of: item.inlines)]
                parts += item.children.map { plainText(of: $0) }
                return parts.filter { !$0.isEmpty }.joined(separator: "\n")
            }.filter { !$0.isEmpty }.joined(separator: "\n")

        case .orderedList(let items, _):
            return items.map { item in
                var parts = [plainText(of: item.inlines)]
                parts += item.children.map { plainText(of: $0) }
                return parts.filter { !$0.isEmpty }.joined(separator: "\n")
            }.filter { !$0.isEmpty }.joined(separator: "\n")

        case .definitionList(let items):
            return items.map { item in
                let termText = item.terms.map { plainText(of: $0) }.joined(separator: "\n")
                let defText  = item.definitions.map { plainText(of: $0) }.joined(separator: "\n")
                return [termText, defText].filter { !$0.isEmpty }.joined(separator: "\n")
            }.filter { !$0.isEmpty }.joined(separator: "\n")

        // ── Table ────────────────────────────────────────────────────────────
        case .table(let table):
            var parts: [String] = []
            if let caption = table.caption {
                parts.append(plainText(of: caption))
            }
            let allRows = table.head + table.body
            for row in allRows {
                let rowText = row.map { plainText(of: $0.inlines) }.filter { !$0.isEmpty }.joined(separator: " ")
                if !rowText.isEmpty { parts.append(rowText) }
            }
            return parts.joined(separator: "\n")

        // ── Preformatted ─────────────────────────────────────────────────────
        case .preformatted(let inlines):
            return plainText(of: inlines)

        // ── Figure ───────────────────────────────────────────────────────────
        case .figure(let image, let caption):
            var parts: [String] = []
            if let alt = image.alt, !alt.isEmpty { parts.append(alt) }
            if let cap = caption { parts.append(plainText(of: cap)) }
            return parts.joined(separator: " ")

        // ── Section / Footnote ───────────────────────────────────────────────
        case .section(_, let blocks):
            return blocks.map { plainText(of: $0) }.joined(separator: "\n")

        case .footnote(_, let blocks):
            return blocks.map { plainText(of: $0) }.joined(separator: "\n")
        }
    }

    /// Extracts plain text from an array of inlines.
    public static func plainText(of inlines: [EPUBInline]) -> String {
        var result = ""
        for inline in inlines {
            switch inline {
            // ── Existing ────────────────────────────────────────────────────
            case .text(let s):
                result += s
            case .emphasis(let inner):
                result += plainText(of: inner)
            case .strong(let inner):
                result += plainText(of: inner)
            case .smallCaps(let inner):
                result += plainText(of: inner)
            case .lineBreak:
                result += "\n"

            // ── New ──────────────────────────────────────────────────────────
            case .superscript(let inner):
                result += plainText(of: inner)
            case .subscript(let inner):
                result += plainText(of: inner)
            case .code(let inner):
                result += plainText(of: inner)
            case .link(_, let inner):
                result += plainText(of: inner)
            case .strikethrough(let inner):
                result += plainText(of: inner)
            case .mark(let inner):
                result += plainText(of: inner)
            case .pageBreakMarker:
                break   // invisible marker — contributes no text
            }
        }
        return result
    }

    /// All plain text in order, with newlines between blocks.
    public func plainText() -> String {
        blocks.map { EPUBContent.plainText(of: $0) }.joined(separator: "\n")
    }
}
