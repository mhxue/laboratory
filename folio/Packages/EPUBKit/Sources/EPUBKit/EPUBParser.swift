import Foundation
import ZIPFoundation

/// Concrete implementation of ``EPUBParsing``.
///
/// Unzips the EPUB archive into `dir`, then parses the OPF package document
/// to extract metadata, spine order, and optional cover art.
public final class EPUBParser: EPUBParsing {

    public init() {}

    // MARK: - EPUBParsing

    public func parse(epubAt url: URL, extractingTo dir: URL) throws -> EPUBDocument {
        // Unzip if not already extracted
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: url, to: dir)
            } catch let zipError where !(zipError is EPUBError) {
                throw EPUBError.notAnEPUB
            }
        }
        return try parseExtracted(at: dir)
    }

    // MARK: - Private helpers

    private func parseExtracted(at root: URL) throws -> EPUBDocument {
        let containerURL = root.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBError.missingContainer
        }

        let opfPath = try parseContainerXML(at: containerURL)
        let opfURL = root.appendingPathComponent(opfPath)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBError.missingOPF
        }

        return try parseOPF(at: opfURL, root: root)
    }

    private func parseContainerXML(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let xmlParser = SimpleXMLParser(data: data)
        xmlParser.parse()
        guard let path = xmlParser.attributes["rootfile"]?["full-path"] else {
            throw EPUBError.missingContainer
        }
        return path
    }

    private func parseOPF(at opfURL: URL, root: URL) throws -> EPUBDocument {
        let data = try Data(contentsOf: opfURL)
        let opfDir = opfURL.deletingLastPathComponent()

        let xmlParser = SimpleXMLParser(data: data)
        xmlParser.parse()

        let title    = xmlParser.textContent["dc:title"]    ?? xmlParser.textContent["title"]    ?? "Unknown Title"

        // Bug 3 fix: prefer role="aut", fall back to first creator, fall back to "Unknown Author"
        let author = xmlParser.creators.first(where: { $0.role == "aut" })?.name
                  ?? xmlParser.creators.first?.name
                  ?? "Unknown Author"

        let language = xmlParser.textContent["dc:language"] ?? xmlParser.textContent["language"]

        // Resolve spine items to file URLs
        let manifestItems = xmlParser.manifestItems   // id -> href
        let manifestAttrs = xmlParser.manifestItemAttrs  // id -> attribute dict
        let spineIDs      = xmlParser.spineOrder      // ordered item ids (linear="no" excluded)

        // Bug 2 fix: build TOC label map from NCX or nav.xhtml
        let tocLabels = parseTOCLabels(opfDir: opfDir, manifestItems: manifestItems, manifestAttrs: manifestAttrs)

        var chapters: [EPUBChapter] = []
        for (index, itemID) in spineIDs.enumerated() {
            guard let href = manifestItems[itemID] else { continue }
            let chapterURL = opfDir.appendingPathComponent(href)
            guard FileManager.default.fileExists(atPath: chapterURL.path) else { continue }

            // Look up label by the bare filename (strip path prefix and fragment)
            let hrefFilename = URL(string: href)?.lastPathComponent ?? href
            let label = tocLabels[hrefFilename] ?? "Chapter \(index + 1)"

            let chapter = EPUBChapter(url: chapterURL, title: label)
            chapters.append(chapter)
        }

        // Cover image
        var coverData: Data?
        if let coverId = xmlParser.coverItemID ?? xmlParser.metaCoverID,
           let coverHref = manifestItems[coverId] {
            let coverURL = opfDir.appendingPathComponent(coverHref)
            coverData = try? Data(contentsOf: coverURL)
        }

        let toc = chapters.enumerated().map { idx, chapter in
            EPUBTOCItem(label: chapter.title, chapterIndex: idx)
        }

        let metadata = EPUBMetadata(
            title: title,
            author: author,
            coverImageData: coverData,
            language: language
        )

        return EPUBDocument(metadata: metadata, chapters: chapters, tableOfContents: toc)
    }

    // MARK: - Bug 2: TOC label parsing

    /// Returns a mapping of filename (without fragment) → label.
    /// Prefers nav.xhtml (EPUB 3) over NCX (EPUB 2) when both exist.
    private func parseTOCLabels(
        opfDir: URL,
        manifestItems: [String: String],
        manifestAttrs: [String: [String: String]]
    ) -> [String: String] {
        // Try nav.xhtml first (EPUB 3)
        for (itemID, attrs) in manifestAttrs {
            if attrs["properties"]?.contains("nav") == true,
               let href = manifestItems[itemID] {
                let navURL = opfDir.appendingPathComponent(href)
                if let data = try? Data(contentsOf: navURL) {
                    let parser = NavXHTMLParser(data: data)
                    parser.parse()
                    if !parser.labels.isEmpty {
                        return parser.labels
                    }
                }
            }
        }

        // Fall back to NCX (EPUB 2)
        for (itemID, attrs) in manifestAttrs {
            if attrs["media-type"] == "application/x-dtbncx+xml",
               let href = manifestItems[itemID] {
                let ncxURL = opfDir.appendingPathComponent(href)
                if let data = try? Data(contentsOf: ncxURL) {
                    let parser = NCXParser(data: data)
                    parser.parse()
                    return parser.labels
                }
            }
        }

        return [:]
    }

    // MARK: - Private inner parsers

    /// SAX parser for EPUB 2 toc.ncx files.
    /// Extracts filename (without fragment) → label from navPoint elements.
    private final class NCXParser: NSObject, XMLParserDelegate, @unchecked Sendable {
        private let data: Data
        private(set) var labels: [String: String] = [:]

        private var currentText = ""
        private var currentLabel = ""
        private var insideNavLabel = false
        private var insideText = false
        private var pendingSrc: String?

        init(data: Data) { self.data = data }

        func parse() {
            let p = XMLParser(data: data)
            p.delegate = self
            p.parse()
        }

        func parser(_ parser: XMLParser,
                    didStartElement element: String,
                    namespaceURI: String?,
                    qualifiedName: String?,
                    attributes elementAttrs: [String: String]) {
            let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
            switch tag {
            case "navpoint":
                currentLabel = ""
                pendingSrc = nil
            case "navlabel":
                insideNavLabel = true
            case "text":
                if insideNavLabel {
                    insideText = true
                    currentText = ""
                }
            case "content":
                if let src = elementAttrs["src"] {
                    // Strip fragment: "file.html#anchor" -> "file.html"
                    let filename = src.components(separatedBy: "#").first ?? src
                    // Also strip directory prefix
                    let bare = URL(string: filename)?.lastPathComponent ?? filename
                    pendingSrc = bare
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideText {
                currentText += string
            }
        }

        func parser(_ parser: XMLParser,
                    didEndElement element: String,
                    namespaceURI: String?,
                    qualifiedName: String?) {
            let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
            switch tag {
            case "text":
                if insideText {
                    currentLabel = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    insideText = false
                }
            case "navlabel":
                insideNavLabel = false
            case "navpoint":
                // Store label for filename; first navPoint per file wins
                if let src = pendingSrc, !currentLabel.isEmpty {
                    if labels[src] == nil {
                        labels[src] = currentLabel
                    }
                }
                currentLabel = ""
                pendingSrc = nil
            default:
                break
            }
        }
    }

    /// SAX parser for EPUB 3 nav.xhtml files.
    /// Extracts filename (without fragment) → label from <nav> <a href="...">text</a> pairs.
    private final class NavXHTMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
        private let data: Data
        private(set) var labels: [String: String] = [:]

        private var insideNav = false
        private var currentHref: String?
        private var currentText = ""
        private var insideAnchor = false

        init(data: Data) { self.data = data }

        func parse() {
            let p = XMLParser(data: data)
            p.delegate = self
            p.parse()
        }

        func parser(_ parser: XMLParser,
                    didStartElement element: String,
                    namespaceURI: String?,
                    qualifiedName: String?,
                    attributes elementAttrs: [String: String]) {
            let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
            switch tag {
            case "nav":
                insideNav = true
            case "a":
                if insideNav, let href = elementAttrs["href"] {
                    let filename = href.components(separatedBy: "#").first ?? href
                    let bare = URL(string: filename)?.lastPathComponent ?? filename
                    currentHref = bare.isEmpty ? nil : bare
                    currentText = ""
                    insideAnchor = true
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideAnchor {
                currentText += string
            }
        }

        func parser(_ parser: XMLParser,
                    didEndElement element: String,
                    namespaceURI: String?,
                    qualifiedName: String?) {
            let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
            switch tag {
            case "nav":
                insideNav = false
            case "a":
                if insideAnchor, let href = currentHref {
                    let label = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !label.isEmpty && labels[href] == nil {
                        labels[href] = label
                    }
                }
                currentHref = nil
                insideAnchor = false
            default:
                break
            }
        }
    }
}

// MARK: - Minimal XML parser (private to EPUBKit)

private final class SimpleXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private let data: Data
    private var currentElement = ""
    private var currentText = ""

    private(set) var textContent: [String: String] = [:]
    private(set) var attributes: [String: [String: String]] = [:]
    private(set) var manifestItems: [String: String] = [:]      // id -> href
    private(set) var manifestItemAttrs: [String: [String: String]] = [:]  // id -> full attrs
    private(set) var spineOrder: [String] = []
    private(set) var coverItemID: String?
    private(set) var metaCoverID: String?

    // Bug 3: collect all creators with their roles
    private(set) var creators: [(name: String, role: String)] = []
    private var pendingCreatorRole: String = ""

    // Bug 4: EPUB 3 meta property tracking
    private var currentMetaProperty: String?
    private var currentMetaRefines: String?

    init(data: Data) { self.data = data }

    func parse() {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement element: String,
                namespaceURI: String?,
                qualifiedName: String?,
                attributes elementAttrs: [String: String]) {
        let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
        currentElement = tag
        currentText = ""
        attributes[tag] = elementAttrs

        switch tag {
        case "item":
            if let id = elementAttrs["id"], let href = elementAttrs["href"] {
                manifestItems[id] = href
                manifestItemAttrs[id] = elementAttrs
                if elementAttrs["properties"]?.contains("cover-image") == true {
                    coverItemID = id
                }
            }
        case "itemref":
            // Bug 1 fix: exclude linear="no" items
            if let idref = elementAttrs["idref"] {
                let linear = elementAttrs["linear"] ?? "yes"
                if linear != "no" {
                    spineOrder.append(idref)
                }
            }
        case "meta":
            // EPUB 2: <meta name="cover" content="id">
            if elementAttrs["name"] == "cover", let content = elementAttrs["content"] {
                metaCoverID = content
            }
            // Bug 4: EPUB 3: <meta property="...">value</meta>
            if let property = elementAttrs["property"] {
                currentMetaProperty = property
                currentMetaRefines = elementAttrs["refines"]
            }
        case "creator":
            // Bug 3: stash the role attribute for this creator element
            pendingCreatorRole = elementAttrs["opf:role"]
                              ?? elementAttrs["role"]
                              ?? ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement element: String,
                namespaceURI: String?,
                qualifiedName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()

        // Bug 3: collect creator
        if tag == "creator" && !trimmed.isEmpty {
            creators.append((name: trimmed, role: pendingCreatorRole))
            pendingCreatorRole = ""
        }

        // Bug 4: EPUB 3 meta property
        if tag == "meta" {
            if let property = currentMetaProperty {
                let key = "meta:\(property)"
                textContent[key] = trimmed
                // Also store refines if present
                if let refines = currentMetaRefines {
                    textContent["meta:\(property):refines:\(refines)"] = trimmed
                }
            }
            currentMetaProperty = nil
            currentMetaRefines = nil
        }

        if !trimmed.isEmpty {
            // Store with both bare tag and full qualified name (e.g. "dc:title")
            textContent[tag] = trimmed
            textContent[element.lowercased()] = trimmed
        }
    }
}
