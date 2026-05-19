import XCTest
@testable import EPUBKit

final class EPUBAddressTests: XCTestCase {

    // MARK: - plainText(of:) — paragraph

    func test_plainText_paragraph() {
        let inlines: [EPUBInline] = [
            .text("Hello "),
            .text("world")
        ]
        let block = EPUBBlock.paragraph(inlines, style: .body)
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "Hello world")
    }

    // MARK: - plainText(of:) — nested emphasis

    func test_plainText_nestedEmphasis() {
        // <p>Normal <em>italic</em> end</p>
        let inlines: [EPUBInline] = [
            .text("Normal "),
            .emphasis([.text("italic")]),
            .text(" end")
        ]
        let block = EPUBBlock.paragraph(inlines, style: .body)
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "Normal italic end")
    }

    // MARK: - plainText(of:) — blockquote with nested blocks

    func test_plainText_blockquote() {
        let inner: [EPUBBlock] = [
            .paragraph([.text("First")], style: .body),
            .paragraph([.text("Second")], style: .body)
        ]
        let block = EPUBBlock.blockquote(inner)
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "First\nSecond")
    }

    // MARK: - EPUBAddress ordering

    func test_address_ordering() {
        let a = EPUBAddress(chapterIndex: 0, blockIndex: 0, charOffset: 0)
        let b = EPUBAddress(chapterIndex: 0, blockIndex: 1, charOffset: 0)
        let c = EPUBAddress(chapterIndex: 1, blockIndex: 0, charOffset: 0)
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
        XCTAssertLessThan(a, c)
    }

    func test_address_charOffset_ordering() {
        let a = EPUBAddress(chapterIndex: 0, blockIndex: 0, charOffset: 5)
        let b = EPUBAddress(chapterIndex: 0, blockIndex: 0, charOffset: 10)
        XCTAssertLessThan(a, b)
    }

    // MARK: - EPUBContent.plainText() (full document)

    func test_content_plainText_joinedWithNewlines() {
        let content = EPUBContent(blocks: [
            .paragraph([.text("Block one")], style: .body),
            .paragraph([.text("Block two")], style: .body)
        ])
        let text = content.plainText()
        XCTAssertEqual(text, "Block one\nBlock two")
    }

    // MARK: - Heading plain text

    func test_plainText_heading() {
        let block = EPUBBlock.heading(level: 1, [.text("Chapter Title")])
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "Chapter Title")
    }

    // MARK: - Image alt text

    func test_plainText_image_withAlt() {
        let block = EPUBBlock.image(src: "img.jpg", alt: "A beautiful image")
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "A beautiful image")
    }

    func test_plainText_image_withoutAlt() {
        let block = EPUBBlock.image(src: "img.jpg", alt: nil)
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "")
    }

    // MARK: - Divider

    func test_plainText_divider() {
        let block = EPUBBlock.divider
        let text = EPUBContent.plainText(of: block)
        XCTAssertEqual(text, "")
    }
}
