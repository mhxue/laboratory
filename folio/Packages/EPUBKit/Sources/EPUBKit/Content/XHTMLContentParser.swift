import Foundation

/// SAX-based XHTML parser that converts a chapter's XHTML into an ``EPUBContent`` AST.
///
/// XHTML is treated as valid XML using Foundation's `XMLParser` — no HTML parser is used.
/// The implementation is a state machine with a block stack and inline stack.
public final class XHTMLContentParser: EPUBContentParsing {

    public init() {}

    public func parse(xhtmlAt url: URL) throws -> EPUBContent {
        let data = try Data(contentsOf: url)
        let delegate = ParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        xmlParser.shouldResolveExternalEntities = false
        xmlParser.parse()
        if let error = delegate.parseError {
            throw error
        }
        return EPUBContent(blocks: delegate.finishedBlocks)
    }
}

// MARK: - Private state-machine delegate

private final class ParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    // Top-level finished blocks
    private(set) var finishedBlocks: [EPUBBlock] = []
    private(set) var parseError: Error?

    // MARK: - Block-level stack

    /// Describes the context of an open block element.
    private enum BlockContext {
        case paragraph(style: EPUBParagraphStyle)
        case heading(level: Int)
        case blockquote        // <blockquote> or <div class="blockquot">
        case figcenter         // <div class="figcenter"> — renders children as centered paragraphs
        case div               // generic <div>
        case skip              // elements whose content should be ignored entirely

        // New contexts
        case section(epubType: String?)
        case footnote(id: String)
        case pre               // <pre> — collect inlines verbatim
        case unorderedList
        case orderedList(start: Int)
        case listItem          // <li> — collect inlines + nested lists
        case definitionList
        case dt                // inside <dl>
        case dd                // inside <dl>
        case table
        case tableCaption
        case tableHead         // inside <thead>
        case tableBody         // inside <tbody> / <tfoot>
        case tableRow(inHead: Bool)
        case tableCell(isHeader: Bool)
        case figure            // <figure>
        case figcaption        // <figcaption>
    }

    // The block-context stack. Each entry carries its collected inlines and child blocks.
    private struct BlockFrame {
        var context: BlockContext
        var inlines: [EPUBInline] = []
        var childBlocks: [EPUBBlock] = []
        // Whether any non-anchor, non-whitespace content has been seen inside this frame.
        var hasSubstantialContent: Bool = false
        // Extra attributes for certain contexts
        var attributes: [String: String] = [:]
    }

    private var blockStack: [BlockFrame] = []

    // MARK: - Inline stack

    /// Describes an open inline element.
    fileprivate enum InlineContext {
        case emphasis    // <i>, <em>
        case strong      // <b>, <strong>
        case smallCaps   // <span class="smcap">
        case skip        // ignore content (e.g. page-number spans)
        case anchor      // <a id="..."> — text inside goes through to parent
        case anchorLink(href: String)  // <a href="..."> — wrap in .link
        case superscript // <sup>
        case `subscript` // <sub>
        case code        // <code> inline
        case strikethrough // <s>, <del>
        case mark        // <mark>
        case transparent // elements whose children are passed through unchanged
    }

    private struct InlineFrame {
        var context: InlineContext
        var inlines: [EPUBInline] = []
    }

    private var inlineStack: [InlineFrame] = []

    // Whether we are inside <body>
    private var inBody = false

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        let tag = localName(element).lowercased()
        let classes = classSet(attributes["class"])

        // Resolve epub:type — may arrive as "epub:type" or via namespace-aware delivery
        let epubTypeAttr = attributes["epub:type"] ?? resolveEpubType(from: attributes, elementNS: namespaceURI)

        // -- Body sentinel --
        if tag == "body" {
            inBody = true
            return
        }
        guard inBody else { return }

        // -- Always-skip elements (head content) --
        if tag == "head" || tag == "style" || tag == "script" || tag == "title" {
            openInline(.skip)
            return
        }

        // -- Check if we're inside a skip block --
        if isInSkipContext() { return }

        // -- Block-level elements --
        if isBlockTag(tag) {
            flushInlinesToCurrentBlock()
            openBlock(tag: tag, classes: classes, attributes: attributes, epubType: epubTypeAttr)
            return
        }

        // -- Inline elements --
        openInlineForTag(tag, classes: classes, attributes: attributes, epubType: epubTypeAttr)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let tag = localName(element).lowercased()
        guard inBody || tag == "body" else { return }

        if tag == "body" {
            inBody = false
            return
        }

        // If we're in a skip context, check if this is the closing tag that pops it
        if isInSkipBlockContext() {
            if isBlockTag(tag) {
                closeSkipBlock()
            }
            return
        }

        if isInSkipInlineContext() {
            if !isBlockTag(tag) {
                closeSkipInline(tag: tag)
            }
            return
        }

        if isBlockTag(tag) {
            closeBlock(tag: tag)
            return
        }

        closeInlineForTag(tag)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inBody else { return }
        guard !inlineStack.isEmpty || !blockStack.isEmpty else { return }

        // If the top inline is a skip context, discard
        if let top = inlineStack.last, case .skip = top.context { return }

        // Check if top block is a skip block
        if let topBlock = blockStack.last, case .skip = topBlock.context { return }

        appendText(string)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }

    // MARK: - Skip context helpers

    private func isInSkipContext() -> Bool {
        isInSkipBlockContext() || isInSkipInlineContext()
    }

    private func isInSkipBlockContext() -> Bool {
        if let top = blockStack.last, case .skip = top.context { return true }
        return false
    }

    private func isInSkipInlineContext() -> Bool {
        if let top = inlineStack.last, case .skip = top.context { return true }
        return false
    }

    private func closeSkipBlock() {
        _ = blockStack.removeLast()
    }

    private func closeSkipInline(tag: String) {
        _ = inlineStack.removeLast()
    }

    // MARK: - Block helpers

    private func isBlockTag(_ tag: String) -> Bool {
        switch tag {
        case "p", "h1", "h2", "h3", "h4", "h5", "h6",
             "div", "hr", "img",
             "blockquote",
             "figure", "figcaption",
             "section", "article", "main", "aside", "nav",
             "header", "footer",
             "pre",
             "ul", "ol", "li",
             "dl", "dt", "dd",
             "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption",
             "colgroup", "col",
             "math", "svg",
             "address":
            return true
        default:
            return false
        }
    }

    private func openBlock(tag: String, classes: Set<String>, attributes: [String: String], epubType: String?) {
        switch tag {
        case "p":
            let style = EPUBParagraphStyle(
                noIndent: classes.contains("nind"),
                centered: classes.contains("r") || classes.contains("center"),
                role: .body
            )
            blockStack.append(BlockFrame(context: .paragraph(style: style)))

        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 1
            blockStack.append(BlockFrame(context: .heading(level: level)))

        case "hr":
            emitBlock(.divider)

        case "img":
            let src = attributes["src"] ?? ""
            let alt = attributes["alt"]
            emitBlock(.image(src: src, alt: alt))

        case "blockquote":
            blockStack.append(BlockFrame(context: .blockquote))

        case "pre":
            blockStack.append(BlockFrame(context: .pre))

        // MARK: Semantic sections
        case "section", "article", "main":
            let resolvedType = epubType ?? attributes["epub:type"]
            blockStack.append(BlockFrame(context: .section(epubType: resolvedType)))

        case "aside":
            let resolvedType = epubType ?? attributes["epub:type"]
            if resolvedType == "footnote" || resolvedType == "endnote" {
                let id = attributes["id"] ?? ""
                blockStack.append(BlockFrame(context: .footnote(id: id)))
            } else {
                blockStack.append(BlockFrame(context: .section(epubType: resolvedType ?? "aside")))
            }

        case "nav":
            // Skip toc nav entirely; also skip any other nav
            blockStack.append(BlockFrame(context: .skip))

        case "header", "footer":
            // Skip structural front/back matter markers
            blockStack.append(BlockFrame(context: .skip))

        case "address":
            // treat like a paragraph
            blockStack.append(BlockFrame(context: .paragraph(style: .body)))

        // MARK: Lists
        case "ul":
            blockStack.append(BlockFrame(context: .unorderedList))

        case "ol":
            let start = attributes["start"].flatMap(Int.init) ?? 1
            blockStack.append(BlockFrame(context: .orderedList(start: start)))

        case "li":
            blockStack.append(BlockFrame(context: .listItem))

        case "dl":
            blockStack.append(BlockFrame(context: .definitionList))

        case "dt":
            blockStack.append(BlockFrame(context: .dt))

        case "dd":
            blockStack.append(BlockFrame(context: .dd))

        // MARK: Table
        case "table":
            blockStack.append(BlockFrame(context: .table))

        case "caption":
            blockStack.append(BlockFrame(context: .tableCaption))

        case "thead":
            blockStack.append(BlockFrame(context: .tableHead))

        case "tbody", "tfoot":
            blockStack.append(BlockFrame(context: .tableBody))

        case "tr":
            // Determine if inside thead
            let inHead = blockStack.last.map { frame in
                if case .tableHead = frame.context { return true }
                return false
            } ?? false
            blockStack.append(BlockFrame(context: .tableRow(inHead: inHead)))

        case "th":
            blockStack.append(BlockFrame(context: .tableCell(isHeader: true)))

        case "td":
            blockStack.append(BlockFrame(context: .tableCell(isHeader: false)))

        case "colgroup", "col":
            blockStack.append(BlockFrame(context: .skip))

        // MARK: Figure
        case "figure":
            blockStack.append(BlockFrame(context: .figure))

        case "figcaption":
            blockStack.append(BlockFrame(context: .figcaption))

        // MARK: Math / SVG — skip entire subtrees
        case "math", "svg":
            blockStack.append(BlockFrame(context: .skip))

        // MARK: div
        case "div":
            let resolvedEpubType = epubType ?? attributes["epub:type"]
            if resolvedEpubType == "pagebreak" {
                // Invisible marker — skip
                blockStack.append(BlockFrame(context: .skip))
            } else if classes.contains("blockquot") {
                blockStack.append(BlockFrame(context: .blockquote))
            } else if classes.contains("figcenter") || classes.contains("figure") {
                blockStack.append(BlockFrame(context: .figcenter))
            } else {
                blockStack.append(BlockFrame(context: .div))
            }

        default:
            blockStack.append(BlockFrame(context: .div))
        }
    }

    private func closeBlock(tag: String) {
        guard !blockStack.isEmpty else { return }

        // For self-closing tags we already emitted and didn't push a frame
        if tag == "hr" || tag == "img" || tag == "col" { return }

        flushInlinesToCurrentBlock()

        let frame = blockStack.removeLast()

        switch frame.context {
        case .skip:
            return

        case .paragraph(let style):
            let inlines = collapseInlines(frame.inlines)
            if !isSubstantialInlines(inlines) { return }
            appendToParent(.paragraph(inlines, style: style))

        case .heading(let level):
            let inlines = collapseInlines(frame.inlines)
            if !isSubstantialInlines(inlines) { return }
            appendToParent(.heading(level: level, inlines))

        case .blockquote:
            var childBlocks = frame.childBlocks
            let directInlines = collapseInlines(frame.inlines)
            if !directInlines.isEmpty {
                childBlocks.append(.paragraph(directInlines, style: .body))
            }
            if childBlocks.isEmpty { return }
            appendToParent(.blockquote(childBlocks))

        case .pre:
            let inlines = collapseInlines(frame.inlines)
            if inlines.isEmpty { return }
            appendToParent(.preformatted(inlines))

        // MARK: Section / Footnote
        case .section(let epubType):
            var childBlocks = frame.childBlocks
            let directInlines = collapseInlines(frame.inlines)
            if isSubstantialInlines(directInlines) {
                childBlocks.insert(.paragraph(directInlines, style: .body), at: 0)
            }
            if childBlocks.isEmpty { return }
            appendToParent(.section(epubType: epubType, childBlocks))

        case .footnote(let id):
            var childBlocks = frame.childBlocks
            let directInlines = collapseInlines(frame.inlines)
            if isSubstantialInlines(directInlines) {
                childBlocks.insert(.paragraph(directInlines, style: .body), at: 0)
            }
            if childBlocks.isEmpty { return }
            appendToParent(.footnote(id: id, childBlocks))

        // MARK: Lists
        case .unorderedList:
            let items = extractListItems(from: frame.childBlocks)
            if items.isEmpty { return }
            appendToParent(.unorderedList(items))

        case .orderedList(let start):
            let items = extractListItems(from: frame.childBlocks)
            if items.isEmpty { return }
            appendToParent(.orderedList(items, start: start))

        case .listItem:
            // List items are collected and converted when the list closes.
            // We produce a synthetic block so the parent list can extract them.
            let inlines = collapseInlines(frame.inlines)
            if !isSubstantialInlines(inlines) && frame.childBlocks.isEmpty { return }
            // Represent as a paragraph so parent list can identify it.
            // We'll use a special encoding: store in childBlocks as a synthetic paragraph
            // that the list-close handler unpacks.
            let syntheticItem = EPUBBlock.paragraph(inlines, style: EPUBParagraphStyle(noIndent: true, centered: false, role: .body))
            // Put as a wrapper: store both inlines and children
            // We use section(epubType: "_listitem", ...) to carry both
            var kids = [EPUBBlock]()
            kids.append(syntheticItem)
            kids.append(contentsOf: frame.childBlocks)
            appendToParent(.section(epubType: "_listitem", kids))

        case .definitionList:
            let items = extractDefinitionItems(from: frame.childBlocks)
            if items.isEmpty { return }
            appendToParent(.definitionList(items))

        case .dt:
            let inlines = collapseInlines(frame.inlines)
            if inlines.isEmpty { return }
            appendToParent(.section(epubType: "_dt", [.paragraph(inlines, style: .body)]))

        case .dd:
            let inlines = collapseInlines(frame.inlines)
            if inlines.isEmpty { return }
            appendToParent(.section(epubType: "_dd", [.paragraph(inlines, style: .body)]))

        // MARK: Table
        case .table:
            let tableBlock = buildTable(from: frame.childBlocks)
            appendToParent(.table(tableBlock))

        case .tableCaption:
            let inlines = collapseInlines(frame.inlines)
            appendToParent(.section(epubType: "_caption", [.paragraph(inlines, style: .body)]))

        case .tableHead:
            // Promote row children (already tagged as _tr_head) up to the table frame.
            for child in frame.childBlocks {
                appendToParent(child)
            }

        case .tableBody:
            // Promote row children (already tagged as _tr_body) up to the table frame.
            for child in frame.childBlocks {
                appendToParent(child)
            }

        case .tableRow(let inHead):
            // Represent row as section(epubType: "_tr_head" or "_tr_body", ...)
            let rowType = inHead ? "_tr_head" : "_tr_body"
            appendToParent(.section(epubType: rowType, frame.childBlocks))

        case .tableCell(let isHeader):
            let inlines = collapseInlines(frame.inlines)
            let epubType = isHeader ? "_th" : "_td"
            appendToParent(.section(epubType: epubType, [.paragraph(inlines, style: .body)]))

        // MARK: Figure
        case .figure:
            let figBlock = buildFigure(from: frame.childBlocks)
            if let figBlock { appendToParent(figBlock) }

        case .figcaption:
            let inlines = collapseInlines(frame.inlines)
            appendToParent(.section(epubType: "_figcaption", [.paragraph(inlines, style: .body)]))

        // MARK: figcenter (legacy class)
        case .figcenter:
            var childBlocks = frame.childBlocks
            let directInlines = collapseInlines(frame.inlines)
            if !directInlines.isEmpty {
                let centeredStyle = EPUBParagraphStyle(noIndent: true, centered: true, role: .caption)
                childBlocks.insert(.paragraph(directInlines, style: centeredStyle), at: 0)
            }
            let remapped: [EPUBBlock] = childBlocks.compactMap { child in
                switch child {
                case .paragraph(let inlines, var style):
                    style.centered = true
                    style.noIndent = true
                    return .paragraph(inlines, style: style)
                case .image:
                    return child
                default:
                    return child
                }
            }
            for block in remapped { appendToParent(block) }

        case .div:
            let directInlines = collapseInlines(frame.inlines)
            var childBlocks = frame.childBlocks
            if isSubstantialInlines(directInlines) {
                childBlocks.insert(.paragraph(directInlines, style: .body), at: 0)
            }
            for block in childBlocks { appendToParent(block) }
        }
    }

    // MARK: - Table close fix for thead

    /// Emit a block that needs no frame (self-contained)
    private func emitBlock(_ block: EPUBBlock) {
        appendToParent(block)
    }

    /// Append a finished block to the parent frame (or to finishedBlocks if at top level).
    private func appendToParent(_ block: EPUBBlock) {
        if blockStack.isEmpty {
            finishedBlocks.append(block)
        } else {
            blockStack[blockStack.count - 1].childBlocks.append(block)
            blockStack[blockStack.count - 1].hasSubstantialContent = true
        }
    }

    // MARK: - List / table builders

    /// Convert list children (encoded as `section(epubType: "_listitem", ...)`) into EPUBListItem.
    private func extractListItems(from blocks: [EPUBBlock]) -> [EPUBListItem] {
        var items: [EPUBListItem] = []
        for block in blocks {
            if case .section(let t, let kids) = block, t == "_listitem" {
                // First child is the paragraph with inlines, rest are nested blocks
                var inlines: [EPUBInline] = []
                var children: [EPUBBlock] = []
                for (i, kid) in kids.enumerated() {
                    if i == 0, case .paragraph(let ki, _) = kid {
                        inlines = ki
                    } else {
                        children.append(kid)
                    }
                }
                items.append(EPUBListItem(inlines: inlines, children: children))
            }
        }
        return items
    }

    /// Convert dl children (encoded as `section(epubType: "_dt"/"_dd", ...)`) into EPUBDefinitionItem.
    private func extractDefinitionItems(from blocks: [EPUBBlock]) -> [EPUBDefinitionItem] {
        var items: [EPUBDefinitionItem] = []
        var currentTerms: [[EPUBInline]] = []
        var currentDefs: [[EPUBInline]] = []

        func flush() {
            if !currentTerms.isEmpty || !currentDefs.isEmpty {
                items.append(EPUBDefinitionItem(terms: currentTerms, definitions: currentDefs))
                currentTerms = []
                currentDefs = []
            }
        }

        for block in blocks {
            guard case .section(let t, let kids) = block else { continue }
            if t == "_dt" {
                // New term — if we already have definitions, flush current item
                if !currentDefs.isEmpty { flush() }
                if let first = kids.first, case .paragraph(let inlines, _) = first {
                    currentTerms.append(inlines)
                }
            } else if t == "_dd" {
                if let first = kids.first, case .paragraph(let inlines, _) = first {
                    currentDefs.append(inlines)
                }
            }
        }
        flush()
        return items
    }

    /// Build EPUBTable from children encoded as synthetic section blocks.
    private func buildTable(from blocks: [EPUBBlock]) -> EPUBTable {
        var caption: [EPUBInline]? = nil
        var headRows: [[EPUBTableCell]] = []
        var bodyRows: [[EPUBTableCell]] = []

        for block in blocks {
            guard case .section(let t, let kids) = block else { continue }
            if t == "_caption" {
                if let first = kids.first, case .paragraph(let inlines, _) = first {
                    caption = inlines.isEmpty ? nil : inlines
                }
            } else if t == "_tr_head" {
                let cells = extractTableCells(from: kids)
                headRows.append(cells)
            } else if t == "_tr_body" {
                let cells = extractTableCells(from: kids)
                bodyRows.append(cells)
            }
        }

        return EPUBTable(caption: caption, head: headRows, body: bodyRows)
    }

    private func extractTableCells(from blocks: [EPUBBlock]) -> [EPUBTableCell] {
        var cells: [EPUBTableCell] = []
        for block in blocks {
            if case .section(let t, let kids) = block {
                let isHeader = (t == "_th")
                var inlines: [EPUBInline] = []
                if let first = kids.first, case .paragraph(let ki, _) = first {
                    inlines = ki
                }
                cells.append(EPUBTableCell(isHeader: isHeader, inlines: inlines))
            }
        }
        return cells
    }

    /// Build EPUBBlock.figure from collected children.
    private func buildFigure(from blocks: [EPUBBlock]) -> EPUBBlock? {
        var figImage: EPUBFigureImage? = nil
        var caption: [EPUBInline]? = nil

        for block in blocks {
            switch block {
            case .image(let src, let alt):
                figImage = EPUBFigureImage(src: src, alt: alt)
            case .section(let t, let kids) where t == "_figcaption":
                if let first = kids.first, case .paragraph(let inlines, _) = first {
                    caption = inlines.isEmpty ? nil : inlines
                }
            default:
                break
            }
        }

        guard let img = figImage else { return nil }
        return .figure(image: img, caption: caption)
    }

    // MARK: - Inline helpers

    private func openInline(_ context: InlineContext) {
        inlineStack.append(InlineFrame(context: context))
    }

    private func openInlineForTag(_ tag: String, classes: Set<String>, attributes: [String: String], epubType: String?) {
        switch tag {
        case "i", "em":
            openInline(.emphasis)
        case "b", "strong":
            openInline(.strong)
        case "sup":
            openInline(.superscript)
        case "sub":
            openInline(.`subscript`)
        case "code":
            openInline(.code)
        case "s", "del":
            openInline(.strikethrough)
        case "mark":
            openInline(.mark)
        case "span":
            let resolvedEpubType = epubType ?? attributes["epub:type"]
            if classes.contains("smcap") {
                openInline(.smallCaps)
            } else if classes.contains("x-ebookmaker-pageno") || classes.contains("pageno") {
                openInline(.skip)
            } else if resolvedEpubType == "pagebreak" {
                // Emit a pageBreakMarker immediately (it's self-contained) and push transparent
                let id = attributes["id"]
                insertInline(.pageBreakMarker(id: id))
                openInline(.skip)  // skip content inside the span
            } else {
                // Transparent span
                openInline(.transparent)
            }
        case "a":
            let resolvedEpubType = epubType ?? attributes["epub:type"]
            if resolvedEpubType == "noteref" {
                // Inline note reference — treat as transparent
                openInline(.transparent)
            } else if let href = attributes["href"], !href.isEmpty {
                openInline(.anchorLink(href: href))
            } else {
                openInline(.anchor)
            }
        case "br":
            insertInline(.lineBreak)
        case "u":
            // Underline — transparent (not semantic in EPUB 3)
            openInline(.transparent)
        case "small", "cite", "dfn", "abbr", "var", "samp", "kbd", "q", "time", "data":
            openInline(.transparent)
        case "ruby":
            openInline(.transparent)
        case "rt", "rp":
            openInline(.skip)
        case "wbr":
            // Zero-width break — skip
            return
        default:
            // Unknown inline — pass through (don't push)
            return
        }
    }

    private func closeInlineForTag(_ tag: String) {
        if tag == "br" || tag == "wbr" { return }

        guard !inlineStack.isEmpty else { return }

        // Find the matching frame to close
        let frame = inlineStack.removeLast()

        switch frame.context {
        case .skip:
            return  // discard content

        case .anchor:
            // Pass through: inject anchor's children directly to the parent
            for inline in frame.inlines {
                insertInline(inline)
            }

        case .anchorLink(let href):
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.link(href: href, inner))

        case .transparent:
            for inline in frame.inlines {
                insertInline(inline)
            }

        case .emphasis:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.emphasis(inner))

        case .strong:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.strong(inner))

        case .smallCaps:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.smallCaps(inner))

        case .superscript:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.superscript(inner))

        case .`subscript`:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.`subscript`(inner))

        case .code:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.code(inner))

        case .strikethrough:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.strikethrough(inner))

        case .mark:
            let inner = collapseInlines(frame.inlines)
            if inner.isEmpty { return }
            insertInline(.mark(inner))
        }
    }

    /// Insert an inline into the current inline context or directly into the block frame.
    private func insertInline(_ inline: EPUBInline) {
        if inlineStack.isEmpty {
            // Add directly to the top block frame
            if !blockStack.isEmpty {
                blockStack[blockStack.count - 1].inlines.append(inline)
                if case .text(let t) = inline, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blockStack[blockStack.count - 1].hasSubstantialContent = true
                } else if case .lineBreak = inline {
                    // lineBreak doesn't count as substantial on its own
                } else {
                    blockStack[blockStack.count - 1].hasSubstantialContent = true
                }
            }
        } else {
            inlineStack[inlineStack.count - 1].inlines.append(inline)
        }
    }

    private func appendText(_ string: String) {
        if !inlineStack.isEmpty {
            if case .skip = inlineStack.last!.context { return }
        }
        insertInline(.text(string))
    }

    /// Flush any pending inline content in the inline stack down to the block frame.
    private func flushInlinesToCurrentBlock() {
        guard inlineStack.isEmpty else { return }
        // No-op: inlines are added directly to the block frame in insertInline
    }

    // MARK: - Inline collapsing

    /// Post-process an inline array: collapse whitespace and remove empty text nodes.
    private func collapseInlines(_ inlines: [EPUBInline]) -> [EPUBInline] {
        var result: [EPUBInline] = []
        for inline in inlines {
            switch inline {
            case .text(let raw):
                let collapsed = collapseWhitespace(raw)
                if !collapsed.isEmpty {
                    if case .text(let prev) = result.last {
                        result[result.count - 1] = .text(prev + " " + collapsed)
                    } else {
                        result.append(.text(collapsed))
                    }
                }
            case .emphasis(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.emphasis(collapsed)) }
            case .strong(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.strong(collapsed)) }
            case .smallCaps(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.smallCaps(collapsed)) }
            case .lineBreak:
                result.append(.lineBreak)
            case .superscript(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.superscript(collapsed)) }
            case .`subscript`(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.`subscript`(collapsed)) }
            case .code(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.code(collapsed)) }
            case .link(let href, let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.link(href: href, collapsed)) }
            case .strikethrough(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.strikethrough(collapsed)) }
            case .mark(let inner):
                let collapsed = collapseInlines(inner)
                if !collapsed.isEmpty { result.append(.mark(collapsed)) }
            case .pageBreakMarker(let id):
                result.append(.pageBreakMarker(id: id))
            }
        }
        // Trim leading/trailing whitespace from first/last text nodes
        if case .text(let first) = result.first {
            let trimmed = first.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { result.removeFirst() } else { result[0] = .text(trimmed) }
        }
        if case .text(let last) = result.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { result.removeLast() } else { result[result.count - 1] = .text(trimmed) }
        }
        return result
    }

    /// Collapse internal whitespace runs to a single space (does not trim ends).
    private func collapseWhitespace(_ string: String) -> String {
        let components = string.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Returns true if the inline array has any non-whitespace content.
    private func isSubstantialInlines(_ inlines: [EPUBInline]) -> Bool {
        for inline in inlines {
            switch inline {
            case .text(let t):
                if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            case .emphasis(let inner), .strong(let inner), .smallCaps(let inner),
                 .superscript(let inner), .`subscript`(let inner), .code(let inner),
                 .strikethrough(let inner), .mark(let inner):
                if isSubstantialInlines(inner) { return true }
            case .link(_, let inner):
                if isSubstantialInlines(inner) { return true }
            case .lineBreak:
                break
            case .pageBreakMarker:
                break
            }
        }
        return false
    }

    // MARK: - Misc helpers

    private func localName(_ element: String) -> String {
        element.components(separatedBy: ":").last ?? element
    }

    private func classSet(_ classAttr: String?) -> Set<String> {
        guard let classAttr else { return [] }
        return Set(classAttr.split(separator: " ").map(String.init))
    }

    /// Resolve epub:type from attributes, handling both "epub:type" key and namespace-aware delivery.
    private func resolveEpubType(from attributes: [String: String], elementNS: String?) -> String? {
        if let v = attributes["epub:type"] { return v }
        // Foundation's XMLParser may strip the namespace prefix and deliver "type"
        // only when the element itself is in the epub namespace — which is rare.
        // Don't auto-promote a bare "type" attribute to avoid false positives.
        return nil
    }
}

// MARK: - InlineContext Equatable conformance (for pattern matching only)

extension ParserDelegate.InlineContext: Equatable {
    static func == (lhs: ParserDelegate.InlineContext, rhs: ParserDelegate.InlineContext) -> Bool {
        switch (lhs, rhs) {
        case (.emphasis, .emphasis), (.strong, .strong), (.smallCaps, .smallCaps),
             (.skip, .skip), (.anchor, .anchor), (.transparent, .transparent),
             (.superscript, .superscript), (.`subscript`, .`subscript`),
             (.code, .code), (.strikethrough, .strikethrough), (.mark, .mark):
            return true
        case (.anchorLink(let a), .anchorLink(let b)):
            return a == b
        default:
            return false
        }
    }
}
