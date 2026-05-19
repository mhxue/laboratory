import XCTest
@testable import EPUBKit

// MARK: - Helpers

private func makeXHTML(_ body: String) -> String {
    """
    <?xml version="1.0" encoding="utf-8"?>
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:epub="http://www.idpf.org/2007/ops">
      <head><title>Test</title></head>
      <body>\(body)</body>
    </html>
    """
}

private func writeTempXHTML(_ xhtml: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("EPUBContentParserTest_\(UUID().uuidString).xhtml")
    try xhtml.data(using: .utf8)!.write(to: url)
    return url
}

// MARK: - Tests

final class EPUBContentParserTests: XCTestCase {

    private func parse(_ body: String) throws -> EPUBContent {
        let xhtml = makeXHTML(body)
        let url = try writeTempXHTML(xhtml)
        defer { try? FileManager.default.removeItem(at: url) }
        return try XHTMLContentParser().parse(xhtmlAt: url)
    }

    // MARK: - Empty body

    func test_emptyBody_returnsNoBlocks() throws {
        let content = try parse("")
        XCTAssertTrue(content.blocks.isEmpty, "Empty body should produce no blocks")
    }

    // MARK: - Single paragraph

    func test_singleParagraph_returnsOneParagraphBlock() throws {
        let content = try parse("<p>Hello world</p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(let inlines, let style) = content.blocks[0] else {
            return XCTFail("Expected paragraph block, got \(content.blocks[0])")
        }
        XCTAssertEqual(inlines.count, 1)
        guard case .text(let text) = inlines[0] else {
            return XCTFail("Expected text inline")
        }
        XCTAssertEqual(text, "Hello world")
        XCTAssertFalse(style.noIndent)
        XCTAssertFalse(style.centered)
        XCTAssertEqual(style.role, .body)
    }

    // MARK: - Emphasis

    func test_paragraphWithEmphasis_returnsInlineEmphasis() throws {
        let content = try parse("<p>Normal <em>italic</em> text</p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(let inlines, _) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        XCTAssertEqual(inlines.count, 3)
        guard case .text(let before) = inlines[0] else {
            return XCTFail("Expected leading text inline")
        }
        XCTAssertEqual(before, "Normal")
        guard case .emphasis(let emphInlines) = inlines[1] else {
            return XCTFail("Expected emphasis inline")
        }
        XCTAssertEqual(emphInlines.count, 1)
        guard case .text(let emphText) = emphInlines[0] else {
            return XCTFail("Expected text inside emphasis")
        }
        XCTAssertEqual(emphText, "italic")
        guard case .text(let after) = inlines[2] else {
            return XCTFail("Expected trailing text inline")
        }
        XCTAssertEqual(after, "text")
    }

    // MARK: - Small caps

    func test_paragraphWithSmcapClass_returnsSmallCapsInline() throws {
        let content = try parse("<p><span class=\"smcap\">Chapter I</span></p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(let inlines, _) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        XCTAssertEqual(inlines.count, 1)
        guard case .smallCaps(let inner) = inlines[0] else {
            return XCTFail("Expected smallCaps inline, got \(inlines[0])")
        }
        XCTAssertEqual(inner.count, 1)
        guard case .text(let t) = inner[0] else {
            return XCTFail("Expected text inside smallCaps")
        }
        XCTAssertEqual(t, "Chapter I")
    }

    // MARK: - Line break

    func test_brInParagraph_insertsLineBreak() throws {
        let content = try parse("<p>Line one<br/>Line two</p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(let inlines, _) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        let hasLineBreak = inlines.contains { inline in
            if case .lineBreak = inline { return true }
            return false
        }
        XCTAssertTrue(hasLineBreak, "Expected lineBreak inline inside paragraph")
    }

    // MARK: - No-indent class

    func test_nindClass_setsNoIndent() throws {
        let content = try parse("<p class=\"nind\">First paragraph</p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(_, let style) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        XCTAssertTrue(style.noIndent, "nind class should set noIndent = true")
    }

    // MARK: - Blockquote div (legacy)

    func test_blockquotDiv_returnsBlockquoteBlock() throws {
        let content = try parse("""
            <div class="blockquot">
                <p>Quoted text here</p>
            </div>
            """)
        XCTAssertEqual(content.blocks.count, 1)
        guard case .blockquote(let inner) = content.blocks[0] else {
            return XCTFail("Expected blockquote block, got \(content.blocks[0])")
        }
        XCTAssertEqual(inner.count, 1)
        guard case .paragraph = inner[0] else {
            return XCTFail("Expected paragraph inside blockquote")
        }
    }

    // MARK: - Figcenter div (legacy)

    func test_figcenterDiv_returnsCenteredParagraph() throws {
        let content = try parse("<div class=\"figcenter\"><p>Caption text</p></div>")
        XCTAssertEqual(content.blocks.count, 1)
        let isCentered: Bool
        switch content.blocks[0] {
        case .paragraph(_, let style):
            isCentered = style.centered
        case .blockquote(let inner):
            if case .paragraph(_, let style) = inner.first {
                isCentered = style.centered
            } else {
                isCentered = false
            }
        default:
            isCentered = false
        }
        XCTAssertTrue(isCentered, "figcenter content should produce centered output")
    }

    // MARK: - Anchor-only elements

    func test_anchorOnlyElement_isSkipped() throws {
        let content = try parse("<a id=\"link1\"/>")
        XCTAssertTrue(content.blocks.isEmpty, "Bare anchor with no text should produce no block")
    }

    func test_divWithOnlyAnchors_isSkipped() throws {
        let content = try parse("<div><a id=\"ch1\"/><a id=\"ch2\"/></div>")
        XCTAssertTrue(content.blocks.isEmpty, "Div containing only anchors should produce no block")
    }

    // MARK: - Nested emphasis

    func test_nestedEmphasis_parsesCorrectly() throws {
        let content = try parse("<p><i>outer <em>inner</em> end</i></p>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .paragraph(let inlines, _) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        XCTAssertEqual(inlines.count, 1, "Should have one top-level inline (the <i>)")
        guard case .emphasis(let outerInlines) = inlines[0] else {
            return XCTFail("Expected emphasis at top level")
        }
        XCTAssertEqual(outerInlines.count, 3, "Outer emphasis should contain 3 inlines")
        guard case .emphasis(let innerInlines) = outerInlines[1] else {
            return XCTFail("Expected nested emphasis inline")
        }
        XCTAssertEqual(innerInlines.count, 1)
        guard case .text(let innerText) = innerInlines[0] else {
            return XCTFail("Expected text inside nested emphasis")
        }
        XCTAssertEqual(innerText, "inner")
    }

    // MARK: - Headings

    func test_h1_returnsHeadingLevel1() throws {
        let content = try parse("<h1>Chapter One</h1>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .heading(let level, let inlines) = content.blocks[0] else {
            return XCTFail("Expected heading block")
        }
        XCTAssertEqual(level, 1)
        guard case .text(let t) = inlines.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "Chapter One")
    }

    func test_h2_returnsHeadingLevel2() throws {
        let content = try parse("<h2>Section Two</h2>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .heading(let level, _) = content.blocks[0] else {
            return XCTFail("Expected heading block")
        }
        XCTAssertEqual(level, 2)
    }

    func test_h3_throughH6_returnCorrectLevels() throws {
        for level in 3...6 {
            let content = try parse("<h\(level)>Head</h\(level)>")
            guard case .heading(let l, _) = content.blocks.first else {
                return XCTFail("Expected heading for h\(level)")
            }
            XCTAssertEqual(l, level, "h\(level) should produce heading level \(level)")
        }
    }

    func test_headingWithEmphasis_preservesInline() throws {
        let content = try parse("<h1>Hello <em>World</em></h1>")
        guard case .heading(_, let inlines) = content.blocks.first else {
            return XCTFail("Expected heading")
        }
        XCTAssertEqual(inlines.count, 2)
        guard case .emphasis(let inner) = inlines[1] else {
            return XCTFail("Expected emphasis in heading")
        }
        guard case .text(let t) = inner.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "World")
    }

    // MARK: - Semantic sections

    func test_sectionElement_returnsSectionBlock() throws {
        let content = try parse("<section><p>Hello</p></section>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .section(_, let children) = content.blocks[0] else {
            return XCTFail("Expected section block, got \(content.blocks[0])")
        }
        XCTAssertFalse(children.isEmpty)
    }

    func test_sectionWithEpubType_preservesType() throws {
        let content = try parse("<section epub:type=\"chapter\"><p>Body text</p></section>")
        guard case .section(let epubType, _) = content.blocks.first else {
            return XCTFail("Expected section block")
        }
        XCTAssertEqual(epubType, "chapter")
    }

    func test_articleElement_returnsSectionBlock() throws {
        let content = try parse("<article><p>Article text</p></article>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .section = content.blocks[0] else {
            return XCTFail("Expected section block for article, got \(content.blocks[0])")
        }
    }

    func test_navWithTocType_isSkipped() throws {
        let content = try parse("<nav epub:type=\"toc\"><ol><li><a href=\"ch1.html\">Chapter 1</a></li></ol></nav>")
        XCTAssertTrue(content.blocks.isEmpty, "nav epub:type=toc should be skipped entirely")
    }

    func test_asideWithFootnoteType_returnsFootnote() throws {
        let content = try parse("<aside id=\"fn1\" epub:type=\"footnote\"><p>Footnote text</p></aside>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .footnote(let id, let children) = content.blocks[0] else {
            return XCTFail("Expected footnote block, got \(content.blocks[0])")
        }
        XCTAssertEqual(id, "fn1")
        XCTAssertFalse(children.isEmpty)
    }

    // MARK: - Blockquote

    func test_blockquoteElement_returnsBlockquote() throws {
        let content = try parse("<blockquote><p>Quoted</p></blockquote>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .blockquote(let inner) = content.blocks[0] else {
            return XCTFail("Expected blockquote, got \(content.blocks[0])")
        }
        XCTAssertFalse(inner.isEmpty)
    }

    func test_blockquoteWithParagraphs_containsBlocks() throws {
        let content = try parse("""
            <blockquote>
                <p>First</p>
                <p>Second</p>
            </blockquote>
            """)
        guard case .blockquote(let inner) = content.blocks.first else {
            return XCTFail("Expected blockquote")
        }
        XCTAssertEqual(inner.count, 2)
    }

    // MARK: - Lists

    func test_unorderedList_returnsUnorderedList() throws {
        let content = try parse("<ul><li>Alpha</li><li>Beta</li></ul>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .unorderedList(let items) = content.blocks[0] else {
            return XCTFail("Expected unorderedList, got \(content.blocks[0])")
        }
        XCTAssertEqual(items.count, 2)
        guard case .text(let t) = items[0].inlines.first else {
            return XCTFail("Expected text in first list item")
        }
        XCTAssertEqual(t, "Alpha")
    }

    func test_orderedList_returnsOrderedList() throws {
        let content = try parse("<ol><li>One</li><li>Two</li></ol>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .orderedList(let items, let start) = content.blocks[0] else {
            return XCTFail("Expected orderedList, got \(content.blocks[0])")
        }
        XCTAssertEqual(start, 1)
        XCTAssertEqual(items.count, 2)
    }

    func test_orderedListWithStart_preservesStart() throws {
        let content = try parse("<ol start=\"5\"><li>Five</li></ol>")
        guard case .orderedList(_, let start) = content.blocks.first else {
            return XCTFail("Expected orderedList")
        }
        XCTAssertEqual(start, 5)
    }

    func test_listItemWithEmphasis_preservesInline() throws {
        let content = try parse("<ul><li>Read <em>this</em></li></ul>")
        guard case .unorderedList(let items) = content.blocks.first else {
            return XCTFail("Expected unorderedList")
        }
        XCTAssertEqual(items.count, 1)
        let inlines = items[0].inlines
        XCTAssertTrue(inlines.contains { if case .emphasis = $0 { return true }; return false },
                      "Expected emphasis in list item")
    }

    func test_nestedList_childrenContainList() throws {
        let content = try parse("""
            <ul>
                <li>Parent
                    <ul>
                        <li>Child</li>
                    </ul>
                </li>
            </ul>
            """)
        guard case .unorderedList(let items) = content.blocks.first else {
            return XCTFail("Expected unorderedList")
        }
        XCTAssertEqual(items.count, 1)
        let children = items[0].children
        XCTAssertFalse(children.isEmpty, "Parent list item should have nested list as child")
        guard case .unorderedList = children.first else {
            return XCTFail("Expected nested unorderedList in children")
        }
    }

    func test_definitionList_returnsDefinitionList() throws {
        let content = try parse("""
            <dl>
                <dt>Term</dt>
                <dd>Definition</dd>
            </dl>
            """)
        XCTAssertEqual(content.blocks.count, 1)
        guard case .definitionList(let items) = content.blocks[0] else {
            return XCTFail("Expected definitionList, got \(content.blocks[0])")
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].terms.count, 1)
        XCTAssertEqual(items[0].definitions.count, 1)
        guard case .text(let t) = items[0].terms[0].first else {
            return XCTFail("Expected text in term")
        }
        XCTAssertEqual(t, "Term")
    }

    func test_definitionListMultipleTerms_groupsCorrectly() throws {
        let content = try parse("""
            <dl>
                <dt>A</dt>
                <dt>B</dt>
                <dd>Def of A and B</dd>
                <dt>C</dt>
                <dd>Def of C</dd>
            </dl>
            """)
        guard case .definitionList(let items) = content.blocks.first else {
            return XCTFail("Expected definitionList")
        }
        // Two items: {terms:[A,B], defs:[Def of A and B]} and {terms:[C], defs:[Def of C]}
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].terms.count, 2)
        XCTAssertEqual(items[0].definitions.count, 1)
        XCTAssertEqual(items[1].terms.count, 1)
        XCTAssertEqual(items[1].definitions.count, 1)
    }

    // MARK: - Table

    func test_simpleTable_returnsTable() throws {
        let content = try parse("""
            <table>
                <tr><td>Cell A</td><td>Cell B</td></tr>
            </table>
            """)
        XCTAssertEqual(content.blocks.count, 1)
        guard case .table(let table) = content.blocks[0] else {
            return XCTFail("Expected table block, got \(content.blocks[0])")
        }
        XCTAssertNil(table.caption)
        XCTAssertTrue(table.head.isEmpty)
        XCTAssertEqual(table.body.count, 1)
        XCTAssertEqual(table.body[0].count, 2)
    }

    func test_tableWithHeader_distinguishesThAndTd() throws {
        let content = try parse("""
            <table>
                <tr><th>Header</th><td>Data</td></tr>
            </table>
            """)
        guard case .table(let table) = content.blocks.first else {
            return XCTFail("Expected table")
        }
        let row = table.body.first ?? table.head.first ?? []
        XCTAssertFalse(row.isEmpty)
        let headerCells = row.filter { $0.isHeader }
        let dataCells = row.filter { !$0.isHeader }
        XCTAssertEqual(headerCells.count, 1, "Expected one th cell")
        XCTAssertEqual(dataCells.count, 1, "Expected one td cell")
    }

    func test_tableWithCaption_captionIsSet() throws {
        let content = try parse("""
            <table>
                <caption>My Table</caption>
                <tr><td>X</td></tr>
            </table>
            """)
        guard case .table(let table) = content.blocks.first else {
            return XCTFail("Expected table")
        }
        XCTAssertNotNil(table.caption, "Caption should be set")
        guard case .text(let cap) = table.caption?.first else {
            return XCTFail("Expected text in caption")
        }
        XCTAssertEqual(cap, "My Table")
    }

    func test_tableWithThead_tbody_separatesCorrectly() throws {
        let content = try parse("""
            <table>
                <thead><tr><th>Col1</th><th>Col2</th></tr></thead>
                <tbody><tr><td>R1C1</td><td>R1C2</td></tr></tbody>
            </table>
            """)
        guard case .table(let table) = content.blocks.first else {
            return XCTFail("Expected table")
        }
        XCTAssertEqual(table.head.count, 1, "Expected 1 head row")
        XCTAssertEqual(table.body.count, 1, "Expected 1 body row")
        XCTAssertTrue(table.head[0].allSatisfy { $0.isHeader }, "All head cells should be headers")
        XCTAssertTrue(table.body[0].allSatisfy { !$0.isHeader }, "All body cells should not be headers")
    }

    // MARK: - Figure

    func test_figureWithImg_returnsFigure() throws {
        let content = try parse("<figure><img src=\"img/cover.jpg\" alt=\"Cover\"/></figure>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .figure(let image, _) = content.blocks[0] else {
            return XCTFail("Expected figure block, got \(content.blocks[0])")
        }
        XCTAssertEqual(image.src, "img/cover.jpg")
        XCTAssertEqual(image.alt, "Cover")
    }

    func test_figureWithCaption_captionIsSet() throws {
        let content = try parse("""
            <figure>
                <img src=\"photo.png\" alt=\"Photo\"/>
                <figcaption>A beautiful photo</figcaption>
            </figure>
            """)
        guard case .figure(_, let caption) = content.blocks.first else {
            return XCTFail("Expected figure")
        }
        XCTAssertNotNil(caption, "Caption should be present")
        guard case .text(let t) = caption?.first else {
            return XCTFail("Expected text in caption")
        }
        XCTAssertEqual(t, "A beautiful photo")
    }

    func test_figureWithoutImg_returnsEmpty() throws {
        // figure with no img should not produce a figure block
        let content = try parse("<figure><figcaption>No image here</figcaption></figure>")
        // Should produce no figure (no img found)
        let hasFigure = content.blocks.contains { if case .figure = $0 { return true }; return false }
        XCTAssertFalse(hasFigure, "Figure without img should not produce a figure block")
    }

    // MARK: - Preformatted

    func test_preElement_returnsPreformatted() throws {
        let content = try parse("<pre>line one\nline two</pre>")
        XCTAssertEqual(content.blocks.count, 1)
        guard case .preformatted(let inlines) = content.blocks[0] else {
            return XCTFail("Expected preformatted block, got \(content.blocks[0])")
        }
        XCTAssertFalse(inlines.isEmpty)
    }

    func test_preWithCode_returnsPreformatted() throws {
        // <pre><code> is common for code blocks; code inside pre is still preformatted
        let content = try parse("<pre><code>let x = 1</code></pre>")
        // The <code> is inline inside <pre>; the pre becomes preformatted
        guard case .preformatted(let inlines) = content.blocks.first else {
            return XCTFail("Expected preformatted block, got \(String(describing: content.blocks.first))")
        }
        let text = EPUBContent.plainText(of: inlines)
        XCTAssertTrue(text.contains("x"), "Plain text should include code content")
    }

    // MARK: - Inlines: strong, b

    func test_strongElement_returnsStrong() throws {
        let content = try parse("<p><strong>Bold</strong></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .strong(let inner) = inlines.first else {
            return XCTFail("Expected strong inline")
        }
        guard case .text(let t) = inner.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "Bold")
    }

    func test_bElement_returnsStrong() throws {
        let content = try parse("<p><b>Bold</b></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .strong = inlines.first else {
            return XCTFail("Expected strong inline for <b>")
        }
    }

    // MARK: - Inlines: sup, sub

    func test_supElement_returnsSuperscript() throws {
        let content = try parse("<p>x<sup>2</sup></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let hasSup = inlines.contains { if case .superscript = $0 { return true }; return false }
        XCTAssertTrue(hasSup, "Expected superscript inline for <sup>")
    }

    func test_subElement_returnsSubscript() throws {
        let content = try parse("<p>H<sub>2</sub>O</p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let hasSub = inlines.contains { if case .`subscript` = $0 { return true }; return false }
        XCTAssertTrue(hasSub, "Expected subscript inline for <sub>")
    }

    // MARK: - Inlines: code

    func test_codeInline_returnsCode() throws {
        let content = try parse("<p>Call <code>foo()</code> now</p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let hasCode = inlines.contains { if case .code = $0 { return true }; return false }
        XCTAssertTrue(hasCode, "Expected code inline for <code>")
    }

    // MARK: - Inlines: link

    func test_aWithHref_returnsLink() throws {
        let content = try parse("<p><a href=\"https://example.com\">Example</a></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .link(let href, let inner) = inlines.first else {
            return XCTFail("Expected link inline, got \(String(describing: inlines.first))")
        }
        XCTAssertEqual(href, "https://example.com")
        guard case .text(let t) = inner.first else { return XCTFail("Expected text in link") }
        XCTAssertEqual(t, "Example")
    }

    func test_aWithoutHref_isTransparent() throws {
        let content = try parse("<p><a id=\"anchor1\">Visible text</a></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        // Should not produce a link, but pass through the text
        let hasLink = inlines.contains { if case .link = $0 { return true }; return false }
        XCTAssertFalse(hasLink, "Anchor without href should not produce a link")
        let hasText = inlines.contains { if case .text = $0 { return true }; return false }
        XCTAssertTrue(hasText, "Anchor text should be preserved")
    }

    // MARK: - Inlines: strikethrough, mark

    func test_sElement_returnsStrikethrough() throws {
        let content = try parse("<p><s>Old text</s></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .strikethrough(let inner) = inlines.first else {
            return XCTFail("Expected strikethrough inline")
        }
        guard case .text(let t) = inner.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "Old text")
    }

    func test_markElement_returnsMark() throws {
        let content = try parse("<p><mark>Highlighted</mark></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .mark(let inner) = inlines.first else {
            return XCTFail("Expected mark inline")
        }
        guard case .text(let t) = inner.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "Highlighted")
    }

    // MARK: - Inlines: transparent elements

    func test_uElement_isTransparent() throws {
        let content = try parse("<p><u>Underlined</u></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        // Should pass through as plain text, no wrapper
        let hasU = inlines.contains { if case .text = $0 { return true }; return false }
        XCTAssertTrue(hasU, "u element should pass through as text")
        // Should not be wrapped in any special inline type
        let hasSpecial = inlines.contains {
            switch $0 {
            case .strikethrough, .mark, .code, .superscript, .`subscript`:
                return true
            default:
                return false
            }
        }
        XCTAssertFalse(hasSpecial, "u element should produce no special wrapper")
    }

    func test_rubyElement_flattensToText() throws {
        let content = try parse("<p><ruby>漢<rt>かん</rt>字<rt>じ</rt></ruby></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        // Should have text content (kanji) but not ruby reading text (rt is skipped)
        let text = EPUBContent.plainText(of: inlines)
        XCTAssertTrue(text.contains("漢"), "Ruby base text should be present")
        XCTAssertFalse(text.contains("かん"), "Ruby annotation (rt) should be skipped")
    }

    func test_rtElement_isSkipped() throws {
        let content = try parse("<p><ruby>Word<rt>pronunciation</rt></ruby></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let text = EPUBContent.plainText(of: inlines)
        XCTAssertFalse(text.contains("pronunciation"), "rt content should be skipped")
    }

    func test_smallElement_isTransparent() throws {
        let content = try parse("<p><small>Fine print</small></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let text = EPUBContent.plainText(of: inlines)
        XCTAssertTrue(text.contains("Fine print"), "small element should pass through text")
    }

    // MARK: - Page break marker

    func test_pageBreakSpan_returnsPageBreakMarker() throws {
        let content = try parse("<p>Text <span epub:type=\"pagebreak\" id=\"p42\"/>more</p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        let hasMarker = inlines.contains { if case .pageBreakMarker = $0 { return true }; return false }
        XCTAssertTrue(hasMarker, "Expected pageBreakMarker inline for epub:type=pagebreak span")
    }

    // MARK: - epub:type semantics

    func test_epubTypeChapter_returnsSectionWithType() throws {
        let content = try parse("<section epub:type=\"chapter\"><h1>Ch 1</h1><p>Body</p></section>")
        guard case .section(let epubType, _) = content.blocks.first else {
            return XCTFail("Expected section block")
        }
        XCTAssertEqual(epubType, "chapter", "epub:type=chapter should be preserved on section")
    }

    func test_epubTypePagebreak_onDiv_isSkipped() throws {
        let content = try parse("<p>Before</p><div epub:type=\"pagebreak\" id=\"p10\"/><p>After</p>")
        // The pagebreak div should be skipped; we get the two paragraphs
        XCTAssertEqual(content.blocks.count, 2, "pagebreak div should be invisible")
        for block in content.blocks {
            guard case .paragraph = block else {
                return XCTFail("Expected only paragraph blocks, got \(block)")
            }
        }
    }

    // MARK: - Plain text extraction

    func test_plainText_unorderedList_joinsItems() throws {
        let content = try parse("<ul><li>Apple</li><li>Banana</li></ul>")
        guard let block = content.blocks.first else { return XCTFail("Expected a block") }
        let text = EPUBContent.plainText(of: block)
        XCTAssertTrue(text.contains("Apple"), "Plain text should contain first item")
        XCTAssertTrue(text.contains("Banana"), "Plain text should contain second item")
    }

    func test_plainText_table_joinsCells() throws {
        let content = try parse("<table><tr><td>Name</td><td>Age</td></tr></table>")
        guard let block = content.blocks.first else { return XCTFail("Expected a block") }
        let text = EPUBContent.plainText(of: block)
        XCTAssertTrue(text.contains("Name"), "Plain text should contain cell content")
        XCTAssertTrue(text.contains("Age"), "Plain text should contain cell content")
    }

    func test_plainText_figure_usesAltAndCaption() throws {
        let content = try parse("""
            <figure>
                <img src="photo.png" alt="A sunset"/>
                <figcaption>Golden hour</figcaption>
            </figure>
            """)
        guard let block = content.blocks.first else { return XCTFail("Expected a block") }
        let text = EPUBContent.plainText(of: block)
        XCTAssertTrue(text.contains("sunset"), "Plain text should include alt text")
        XCTAssertTrue(text.contains("Golden"), "Plain text should include caption")
    }

    func test_plainText_superscript_includesText() throws {
        let content = try parse("<p>E = mc<sup>2</sup></p>")
        guard let block = content.blocks.first else { return XCTFail("Expected a block") }
        let text = EPUBContent.plainText(of: block)
        XCTAssertTrue(text.contains("2"), "Plain text should include superscript content")
    }

    func test_plainText_link_includesLinkText() throws {
        let content = try parse("<p>See <a href=\"https://example.com\">this page</a></p>")
        guard let block = content.blocks.first else { return XCTFail("Expected a block") }
        let text = EPUBContent.plainText(of: block)
        XCTAssertTrue(text.contains("this page"), "Plain text should include link text")
    }

    // MARK: - Edge cases

    func test_emptyListItem_isSkipped() throws {
        let content = try parse("<ul><li>   </li><li>Real item</li></ul>")
        guard case .unorderedList(let items) = content.blocks.first else {
            return XCTFail("Expected unorderedList")
        }
        // Whitespace-only item should be dropped
        XCTAssertEqual(items.count, 1, "Empty list items should be skipped")
        guard case .text(let t) = items[0].inlines.first else {
            return XCTFail("Expected text in list item")
        }
        XCTAssertEqual(t, "Real item")
    }

    func test_nestedInlines_deeplyNested() throws {
        let content = try parse("<p><strong><em><code>deep</code></em></strong></p>")
        guard case .paragraph(let inlines, _) = content.blocks.first else {
            return XCTFail("Expected paragraph")
        }
        guard case .strong(let sInner) = inlines.first else { return XCTFail("Expected strong") }
        guard case .emphasis(let eInner) = sInner.first else { return XCTFail("Expected emphasis") }
        guard case .code(let cInner) = eInner.first else { return XCTFail("Expected code") }
        guard case .text(let t) = cInner.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "deep")
    }

    func test_mixedBlocksAndInlines_parsesCorrectly() throws {
        let content = try parse("""
            <section>
                <h1>Title</h1>
                <p>Paragraph one</p>
                <ul><li>Item</li></ul>
            </section>
            """)
        XCTAssertEqual(content.blocks.count, 1)
        guard case .section(_, let children) = content.blocks[0] else {
            return XCTFail("Expected section")
        }
        XCTAssertEqual(children.count, 3, "Section should have heading, paragraph, and list")
    }

    func test_whitespaceOnlyParagraph_isDropped() throws {
        let content = try parse("<p>   \n   </p><p>Real content</p>")
        // Whitespace-only paragraph should be dropped
        XCTAssertEqual(content.blocks.count, 1, "Whitespace-only paragraph should be dropped")
        guard case .paragraph(let inlines, _) = content.blocks[0] else {
            return XCTFail("Expected paragraph")
        }
        guard case .text(let t) = inlines.first else { return XCTFail("Expected text") }
        XCTAssertEqual(t, "Real content")
    }

    func test_mathElement_isSkipped() throws {
        let content = try parse("""
            <p>Before</p>
            <math xmlns="http://www.w3.org/1998/Math/MathML"><mrow><mn>42</mn></mrow></math>
            <p>After</p>
            """)
        // math block should be skipped
        XCTAssertEqual(content.blocks.count, 2, "math element should be skipped")
        for block in content.blocks {
            guard case .paragraph = block else {
                return XCTFail("Expected only paragraph blocks, got \(block)")
            }
        }
    }

    func test_svgElement_isSkipped() throws {
        let content = try parse("""
            <p>Before</p>
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                <circle cx="50" cy="50" r="40"/>
            </svg>
            <p>After</p>
            """)
        // svg block should be skipped
        XCTAssertEqual(content.blocks.count, 2, "svg element should be skipped")
    }
}
