import Foundation

/// Structured representation of one EPUB chapter's content.
/// No HTML — pure semantic document model.
public struct EPUBContent: Sendable {
    public let blocks: [EPUBBlock]
    public init(blocks: [EPUBBlock]) { self.blocks = blocks }
}

public indirect enum EPUBBlock: Sendable {
    // ── Existing cases (do not remove) ──────────────────────────────────────
    case paragraph([EPUBInline], style: EPUBParagraphStyle)
    case heading(level: Int, [EPUBInline])
    case blockquote([EPUBBlock])
    case image(src: String, alt: String?)
    case divider   // <hr> or page-break class

    // ── Lists ────────────────────────────────────────────────────────────────
    case unorderedList([EPUBListItem])
    case orderedList([EPUBListItem], start: Int)   // start= for lists beginning at non-1
    case definitionList([EPUBDefinitionItem])

    // ── Table ────────────────────────────────────────────────────────────────
    case table(EPUBTable)

    // ── Preformatted / code block ─────────────────────────────────────────────
    case preformatted([EPUBInline])    // <pre>

    // ── Figure ───────────────────────────────────────────────────────────────
    case figure(image: EPUBFigureImage, caption: [EPUBInline]?)

    // ── Section wrapper ───────────────────────────────────────────────────────
    case section(epubType: String?, [EPUBBlock])

    // ── Footnote / endnote ───────────────────────────────────────────────────
    case footnote(id: String, [EPUBBlock])
}

public enum EPUBInline: Sendable {
    // ── Existing cases (do not remove) ──────────────────────────────────────
    case text(String)
    case emphasis([EPUBInline])       // <i>, <em>
    case strong([EPUBInline])         // <b>, <strong>
    case smallCaps([EPUBInline])      // class="smcap"
    case lineBreak                    // <br/>

    // ── New inline cases ─────────────────────────────────────────────────────
    case superscript([EPUBInline])          // <sup>
    case `subscript`([EPUBInline])          // <sub>
    case code([EPUBInline])                 // <code> inline
    case link(href: String, [EPUBInline])   // <a href="...">
    case strikethrough([EPUBInline])        // <s>, <del>
    case mark([EPUBInline])                 // <mark>
    case pageBreakMarker(id: String?)       // epub:type="pagebreak"
}

public struct EPUBParagraphStyle: Sendable, Equatable {
    public var noIndent: Bool     // class="nind" or first paragraph
    public var centered: Bool     // class="r" or figcenter
    public var role: EPUBParagraphRole
    public static let body = EPUBParagraphStyle(noIndent: false, centered: false, role: .body)
    public init(noIndent: Bool, centered: Bool, role: EPUBParagraphRole) {
        self.noIndent = noIndent
        self.centered = centered
        self.role = role
    }
}

public enum EPUBParagraphRole: Sendable {
    case body, caption, attribution
}

// MARK: - Supporting types

public struct EPUBListItem: Sendable {
    public let inlines: [EPUBInline]
    public let children: [EPUBBlock]   // for nested lists
    public init(inlines: [EPUBInline], children: [EPUBBlock] = []) {
        self.inlines = inlines
        self.children = children
    }
}

public struct EPUBDefinitionItem: Sendable {
    public let terms: [[EPUBInline]]        // <dt> entries
    public let definitions: [[EPUBInline]]  // <dd> entries
    public init(terms: [[EPUBInline]], definitions: [[EPUBInline]]) {
        self.terms = terms
        self.definitions = definitions
    }
}

public struct EPUBTable: Sendable {
    public let caption: [EPUBInline]?
    public let head: [[EPUBTableCell]]    // thead rows
    public let body: [[EPUBTableCell]]    // tbody + bare tr rows
    public init(caption: [EPUBInline]?, head: [[EPUBTableCell]], body: [[EPUBTableCell]]) {
        self.caption = caption
        self.head = head
        self.body = body
    }
}

public struct EPUBTableCell: Sendable {
    public let isHeader: Bool
    public let inlines: [EPUBInline]
    public init(isHeader: Bool, inlines: [EPUBInline]) {
        self.isHeader = isHeader
        self.inlines = inlines
    }
}

public struct EPUBFigureImage: Sendable {
    public let src: String
    public let alt: String?
    public init(src: String, alt: String?) {
        self.src = src
        self.alt = alt
    }
}
