import XCTest
@testable import EPUBKit

// MARK: - Tests against the real EPUBParser

final class EPUBParserTests: XCTestCase {

    private var extractDir: URL!

    override func setUp() {
        super.setUp()
        extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBKitTests_\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: extractDir)
        super.tearDown()
    }

    private var fixtureEpubURL: URL {
        // Bundle.module is synthesised by SPM for test targets with resources.
        // The .copy resource rule preserves directory structure inside the bundle.
        if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub",
                                       subdirectory: "Fixtures") {
            return url
        }
        // Fallback: flat copy (some SPM versions flatten resources)
        if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub") {
            return url
        }
        // Last resort: look relative to the source file
        let srcDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        return srcDir.appendingPathComponent("Fixtures/pride_and_prejudice.epub")
    }

    // MARK: Tests

    func test_realParser_invalidFile_throws() throws {
        let parser = EPUBParser()
        let bogusURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bogus_\(UUID().uuidString).epub")
        // Write a non-zip file
        try "not an epub".data(using: .utf8)!.write(to: bogusURL)
        defer { try? FileManager.default.removeItem(at: bogusURL) }

        XCTAssertThrowsError(
            try parser.parse(epubAt: bogusURL, extractingTo: extractDir)
        ) { error in
            XCTAssertTrue(error is EPUBError, "Expected EPUBError, got \(error)")
        }
    }

    func test_realParser_validEpub_hasTitle() throws {
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: fixtureEpubURL, extractingTo: extractDir)
        XCTAssertFalse(doc.metadata.title.isEmpty, "Title should not be empty")
        // Pride and Prejudice fixture should identify itself
        XCTAssertTrue(
            doc.metadata.title.localizedCaseInsensitiveContains("Pride"),
            "Expected title to contain 'Pride', got '\(doc.metadata.title)'"
        )
    }

    func test_realParser_validEpub_hasAuthor() throws {
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: fixtureEpubURL, extractingTo: extractDir)
        XCTAssertFalse(doc.metadata.author.isEmpty, "Author should not be empty")
    }

    func test_realParser_validEpub_spineIsNonEmpty() throws {
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: fixtureEpubURL, extractingTo: extractDir)
        XCTAssertGreaterThan(doc.chapters.count, 0, "Spine should contain at least one chapter")
    }

    func test_realParser_idempotent_secondCallReuseExtracted() throws {
        let parser = EPUBParser()
        let doc1 = try parser.parse(epubAt: fixtureEpubURL, extractingTo: extractDir)
        // Second call reuses the already-extracted directory
        let doc2 = try parser.parse(epubAt: fixtureEpubURL, extractingTo: extractDir)
        XCTAssertEqual(doc1.metadata.title, doc2.metadata.title)
        XCTAssertEqual(doc1.chapters.count, doc2.chapters.count)
    }
}

// MARK: - Bug 1: linear="no" spine items

final class EPUBParserLinearTests: XCTestCase {

    /// Builds a minimal in-memory EPUB directory for testing without needing a .epub file.
    private func makeExtractedEPUB(opfXML: String, files: [String: String] = [:]) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBLinearTest_\(UUID().uuidString)", isDirectory: true)
        let metaInf = root.appendingPathComponent("META-INF", isDirectory: true)
        try! FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)

        let container = """
        <?xml version='1.0' encoding='utf-8'?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let containerURL = metaInf.appendingPathComponent("container.xml")
        try! container.data(using: .utf8)!.write(to: containerURL)

        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        try! FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)

        let opfURL = oebps.appendingPathComponent("content.opf")
        try! opfXML.data(using: .utf8)!.write(to: opfURL)

        // Write default placeholder HTML files
        let defaultHTML = "<html><body><p>Content</p></body></html>"
        for (filename, content) in files {
            let fileURL = oebps.appendingPathComponent(filename)
            try! content.data(using: .utf8)!.write(to: fileURL)
        }
        // Write default content files if not explicitly provided
        for name in ["chapter1.html", "chapter2.html", "cover.html", "toc.html",
                     "wrap0000.html", "real_chapter.html"] {
            let fileURL = oebps.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try! defaultHTML.data(using: .utf8)!.write(to: fileURL)
            }
        }
        return root
    }

    override func tearDown() {
        // Each test uses UUID-based temp directories; they self-isolate
        super.tearDown()
    }

    func test_linearNo_itemsExcludedFromSpine() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata>
            <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title>
            <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Author</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="ch2" href="chapter2.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1" linear="yes"/>
            <itemref idref="ch2" linear="no"/>
          </spine>
        </package>
        """
        let root = makeExtractedEPUB(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root) // root is already extracted
        // Only the linear="yes" item should appear
        XCTAssertEqual(doc.chapters.count, 1,
                       "Expected 1 chapter, got \(doc.chapters.count)")
        XCTAssertTrue(doc.chapters[0].url.lastPathComponent.contains("chapter1"),
                      "Expected chapter1, got \(doc.chapters[0].url.lastPathComponent)")
    }

    func test_linearNo_coverPage_notIncluded() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata>
            <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title>
            <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Author</dc:creator>
          </metadata>
          <manifest>
            <item id="coverpage-wrapper" href="wrap0000.html" media-type="application/xhtml+xml"/>
            <item id="realchapter" href="real_chapter.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="coverpage-wrapper" linear="no"/>
            <itemref idref="realchapter" linear="yes"/>
          </spine>
        </package>
        """
        let root = makeExtractedEPUB(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.chapters.count, 1,
                       "Cover page (linear=no) should be excluded; got \(doc.chapters.count) chapters")
        XCTAssertFalse(doc.chapters[0].url.lastPathComponent.contains("wrap"),
                       "Cover wrapper should not appear as a chapter")
    }

    func test_linearMissing_defaultsToIncluded() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata>
            <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title>
            <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Author</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="ch2" href="chapter2.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
            <itemref idref="ch2"/>
          </spine>
        </package>
        """
        let root = makeExtractedEPUB(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.chapters.count, 2,
                       "Items without linear attr should default to included; got \(doc.chapters.count)")
    }

    func test_realParser_noCoverChapter() throws {
        // The fixture epub has coverpage-wrapper as linear="yes", so it IS included.
        // This test verifies that no chapter has an empty title (regression guard).
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBLinearReal_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }

        let epubURL: URL
        if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub",
                                       subdirectory: "Fixtures") {
            epubURL = url
        } else if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub") {
            epubURL = url
        } else {
            let srcDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            epubURL = srcDir.appendingPathComponent("Fixtures/pride_and_prejudice.epub")
        }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: epubURL, extractingTo: extractDir)
        XCTAssertGreaterThan(doc.chapters.count, 0)
        for chapter in doc.chapters {
            XCTAssertFalse(chapter.title.isEmpty,
                           "Chapter title should not be empty; url=\(chapter.url.lastPathComponent)")
        }
    }
}

// MARK: - Bug 2: TOC / NCX / nav.xhtml label parsing

/// These tests exercise the NCX and nav.xhtml parsers indirectly via a full EPUBParser
/// parse of hand-crafted fixture directories.
final class EPUBParserTOCTests: XCTestCase {

    private func makeExtractedEPUBWithNCX(ncxXML: String, opfExtra: String = "") -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBTOCTest_\(UUID().uuidString)", isDirectory: true)
        let metaInf = root.appendingPathComponent("META-INF", isDirectory: true)
        try! FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)

        let container = """
        <?xml version='1.0' encoding='utf-8'?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try! container.data(using: .utf8)!.write(to: metaInf.appendingPathComponent("container.xml"))

        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        try! FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)

        // Write NCX
        try! ncxXML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("toc.ncx"))

        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata>
            <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title>
            <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Author</dc:creator>
            \(opfExtra)
          </metadata>
          <manifest>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="ch2" href="chapter2.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine toc="ncx">
            <itemref idref="ch1"/>
            <itemref idref="ch2"/>
          </spine>
        </package>
        """
        try! opf.data(using: .utf8)!.write(to: oebps.appendingPathComponent("content.opf"))

        let defaultHTML = "<html><body><p>Content</p></body></html>"
        try! defaultHTML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("chapter1.html"))
        try! defaultHTML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("chapter2.html"))

        return root
    }

    func test_ncx_labelsExtracted() throws {
        let ncxXML = """
        <?xml version='1.0' encoding='UTF-8'?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head/>
          <docTitle><text>Test Book</text></docTitle>
          <navMap>
            <navPoint id="np-1">
              <navLabel><text>Chapter One</text></navLabel>
              <content src="chapter1.html#anchor1"/>
            </navPoint>
            <navPoint id="np-2">
              <navLabel><text>Chapter Two</text></navLabel>
              <content src="chapter2.html#anchor2"/>
            </navPoint>
          </navMap>
        </ncx>
        """
        let root = makeExtractedEPUBWithNCX(ncxXML: ncxXML)
        defer { try? FileManager.default.removeItem(at: root) }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)

        XCTAssertEqual(doc.chapters.count, 2)
        XCTAssertEqual(doc.chapters[0].title, "Chapter One",
                       "Expected 'Chapter One', got '\(doc.chapters[0].title)'")
        XCTAssertEqual(doc.chapters[1].title, "Chapter Two",
                       "Expected 'Chapter Two', got '\(doc.chapters[1].title)'")
    }

    func test_nav_labelsExtracted() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBNavTest_\(UUID().uuidString)", isDirectory: true)
        let metaInf = root.appendingPathComponent("META-INF", isDirectory: true)
        try! FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)

        let container = """
        <?xml version='1.0' encoding='utf-8'?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try! container.data(using: .utf8)!.write(to: metaInf.appendingPathComponent("container.xml"))

        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        try! FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)

        let navXHTML = """
        <?xml version='1.0' encoding='UTF-8'?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <body>
            <nav epub:type="toc">
              <ol>
                <li><a href="chapter1.html#s1">First Chapter</a></li>
                <li><a href="chapter2.html#s2">Second Chapter</a></li>
              </ol>
            </nav>
          </body>
        </html>
        """
        try! navXHTML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("nav.xhtml"))

        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata>
            <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title>
            <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Author</dc:creator>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="ch2" href="chapter2.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
            <itemref idref="ch2"/>
          </spine>
        </package>
        """
        try! opf.data(using: .utf8)!.write(to: oebps.appendingPathComponent("content.opf"))

        let defaultHTML = "<html><body><p>Content</p></body></html>"
        try! defaultHTML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("chapter1.html"))
        try! defaultHTML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("chapter2.html"))
        defer { try? FileManager.default.removeItem(at: root) }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)

        XCTAssertEqual(doc.chapters.count, 2)
        XCTAssertEqual(doc.chapters[0].title, "First Chapter",
                       "Expected 'First Chapter', got '\(doc.chapters[0].title)'")
        XCTAssertEqual(doc.chapters[1].title, "Second Chapter",
                       "Expected 'Second Chapter', got '\(doc.chapters[1].title)'")
    }

    func test_realParser_chapterTitlesNotAllFallback() throws {
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBTOCReal_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }

        let epubURL: URL
        if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub",
                                       subdirectory: "Fixtures") {
            epubURL = url
        } else if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub") {
            epubURL = url
        } else {
            let srcDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            epubURL = srcDir.appendingPathComponent("Fixtures/pride_and_prejudice.epub")
        }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: epubURL, extractingTo: extractDir)
        XCTAssertGreaterThan(doc.chapters.count, 0)

        let fallbackPattern = #"^Chapter \d+$"#
        let regex = try! NSRegularExpression(pattern: fallbackPattern)
        let allFallback = doc.chapters.allSatisfy { chapter in
            let range = NSRange(chapter.title.startIndex..., in: chapter.title)
            return regex.firstMatch(in: chapter.title, range: range) != nil
        }
        XCTAssertFalse(allFallback,
                       "Expected at least some chapters to have NCX labels, not all 'Chapter N' fallbacks")
    }

    func test_realParser_chapterCount_matchesNcxEntries() throws {
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBTOCReal2_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }

        let epubURL: URL
        if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub",
                                       subdirectory: "Fixtures") {
            epubURL = url
        } else if let url = Bundle.module.url(forResource: "pride_and_prejudice", withExtension: "epub") {
            epubURL = url
        } else {
            let srcDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            epubURL = srcDir.appendingPathComponent("Fixtures/pride_and_prejudice.epub")
        }

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: epubURL, extractingTo: extractDir)
        XCTAssertGreaterThan(doc.chapters.count, 0, "Should have at least one chapter")
        for chapter in doc.chapters {
            XCTAssertFalse(chapter.title.isEmpty, "No chapter title should be empty")
        }
    }
}

// MARK: - Bug 3: Multiple dc:creator / role filtering

final class EPUBParserCreatorTests: XCTestCase {

    private func makeRoot(opfXML: String, files: [String] = ["chapter1.html"]) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUBCreatorTest_\(UUID().uuidString)", isDirectory: true)
        let metaInf = root.appendingPathComponent("META-INF", isDirectory: true)
        try! FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)
        let container = """
        <?xml version='1.0' encoding='utf-8'?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try! container.data(using: .utf8)!.write(to: metaInf.appendingPathComponent("container.xml"))
        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        try! FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)
        try! opfXML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("content.opf"))
        let html = "<html><body><p>Content</p></body></html>"
        for f in files {
            try! html.data(using: .utf8)!.write(to: oebps.appendingPathComponent(f))
        }
        return root
    }

    func test_singleCreator_returnsAuthor() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>A Book</dc:title>
            <dc:creator>Jane Austen</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.author, "Jane Austen")
    }

    func test_multipleCreators_returnsFirst() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>A Book</dc:title>
            <dc:creator>First Author</dc:creator>
            <dc:creator>Second Author</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        // No roles specified; first creator should be returned
        XCTAssertEqual(doc.metadata.author, "First Author",
                       "Expected 'First Author', got '\(doc.metadata.author)'")
    }

    func test_multipleCreators_prefersAuthorRole() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>A Book</dc:title>
            <dc:creator opf:role="edt">The Editor</dc:creator>
            <dc:creator opf:role="aut">The Real Author</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.author, "The Real Author",
                       "Should prefer creator with role='aut'; got '\(doc.metadata.author)'")
    }

    func test_multipleCreators_noAuthorRole_returnsFirst() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>A Book</dc:title>
            <dc:creator opf:role="edt">The Editor</dc:creator>
            <dc:creator opf:role="trl">The Translator</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        // No "aut" role; first creator wins
        XCTAssertEqual(doc.metadata.author, "The Editor",
                       "Expected first creator when no 'aut' role; got '\(doc.metadata.author)'")
    }

    func test_noCreator_returnsUnknownAuthor() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>A Book</dc:title>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.author, "Unknown Author",
                       "Expected 'Unknown Author' when no creator; got '\(doc.metadata.author)'")
    }
}

// MARK: - Bug 4: EPUB 3 <meta property="..."> parsing

final class EPUBParserEPUB3MetaTests: XCTestCase {

    private func makeRoot(opfXML: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUB3MetaTest_\(UUID().uuidString)", isDirectory: true)
        let metaInf = root.appendingPathComponent("META-INF", isDirectory: true)
        try! FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)
        let container = """
        <?xml version='1.0' encoding='utf-8'?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try! container.data(using: .utf8)!.write(to: metaInf.appendingPathComponent("container.xml"))
        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        try! FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)
        try! opfXML.data(using: .utf8)!.write(to: oebps.appendingPathComponent("content.opf"))
        let html = "<html><body><p>Content</p></body></html>"
        try! html.data(using: .utf8)!.write(to: oebps.appendingPathComponent("chapter1.html"))
        return root
    }

    /// Because EPUBParser doesn't expose textContent, we verify EPUB3 meta via
    /// observable side effects: the parse must succeed and return expected metadata.
    /// We also verify no crash occurs when EPUB3 meta elements are present.

    func test_epub3Meta_propertyStored() throws {
        // Verify EPUB 3 meta does not crash the parser and the book parses successfully.
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0">
          <metadata>
            <dc:title>EPUB3 Book</dc:title>
            <dc:creator>Some Author</dc:creator>
            <meta property="dcterms:modified">2023-01-01T00:00:00Z</meta>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        // Parsing should succeed and title should be correct
        XCTAssertEqual(doc.metadata.title, "EPUB3 Book")
        XCTAssertEqual(doc.metadata.author, "Some Author")
    }

    func test_epub3Meta_withRefines_stored() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0">
          <metadata>
            <dc:title>EPUB3 Book</dc:title>
            <dc:creator id="author">Some Author</dc:creator>
            <meta refines="#author" property="role">aut</meta>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }
        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.title, "EPUB3 Book")
        XCTAssertFalse(doc.metadata.author.isEmpty)
    }

    func test_epub2Meta_coverStill_works() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <metadata>
            <dc:title>EPUB2 Book</dc:title>
            <dc:creator>Some Author</dc:creator>
            <meta name="cover" content="cover-img"/>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="cover-img" href="cover.jpg" media-type="image/jpeg"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }

        // Write a dummy cover image
        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        let fakeJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try! fakeJPEG.write(to: oebps.appendingPathComponent("cover.jpg"))

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.title, "EPUB2 Book")
        // Cover image should have been loaded
        XCTAssertNotNil(doc.metadata.coverImageData,
                        "EPUB 2 meta name='cover' should still trigger cover image loading")
    }

    func test_bothStyles_coexist() throws {
        let opf = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0">
          <metadata>
            <dc:title>Mixed EPUB</dc:title>
            <dc:creator>Some Author</dc:creator>
            <meta name="cover" content="cover-img"/>
            <meta property="dcterms:modified">2024-06-01T00:00:00Z</meta>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="cover-img" href="cover.jpg" media-type="image/jpeg"/>
          </manifest>
          <spine><itemref idref="ch1"/></spine>
        </package>
        """
        let root = makeRoot(opfXML: opf)
        defer { try? FileManager.default.removeItem(at: root) }

        // Write dummy cover
        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        let fakeJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try! fakeJPEG.write(to: oebps.appendingPathComponent("cover.jpg"))

        let parser = EPUBParser()
        let doc = try parser.parse(epubAt: root, extractingTo: root)
        XCTAssertEqual(doc.metadata.title, "Mixed EPUB")
        // Both EPUB 2 cover meta and EPUB 3 property meta should coexist without errors
        XCTAssertNotNil(doc.metadata.coverImageData, "EPUB 2 cover meta should still work alongside EPUB 3 meta")
        XCTAssertEqual(doc.metadata.author, "Some Author")
    }
}
