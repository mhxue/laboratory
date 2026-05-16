import Foundation
import ZIPFoundation

enum EPUBError: LocalizedError {
    case notAnEPUB
    case missingContainer
    case missingOPF
    case malformedOPF

    var errorDescription: String? {
        switch self {
        case .notAnEPUB: return "File is not a valid EPUB archive."
        case .missingContainer: return "Missing META-INF/container.xml."
        case .missingOPF: return "Could not locate OPF package document."
        case .malformedOPF: return "OPF package document is malformed."
        }
    }
}

final class EPUBParser {

    // Unzip epub to Caches/Extracted/{id}/ and return metadata.
    func parse(epubURL: URL, bookID: UUID) throws -> EPUBMetadata {
        let extractDir = extractionDirectory(for: bookID)
        if !FileManager.default.fileExists(atPath: extractDir.path) {
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: epubURL, to: extractDir)
        }
        return try parseExtracted(at: extractDir)
    }

    func chapterURLs(for bookID: UUID) throws -> [URL] {
        let extractDir = extractionDirectory(for: bookID)
        let meta = try parseExtracted(at: extractDir)
        return meta.chapterURLs
    }

    func extractionDirectory(for bookID: UUID) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Extracted/\(bookID.uuidString)", isDirectory: true)
    }

    // MARK: - Private

    private func parseExtracted(at root: URL) throws -> EPUBMetadata {
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
        let parser = SimpleXMLParser(data: data)
        parser.parse()
        guard let path = parser.attributes["rootfile"]?["full-path"] else {
            throw EPUBError.missingContainer
        }
        return path
    }

    private func parseOPF(at opfURL: URL, root: URL) throws -> EPUBMetadata {
        let data = try Data(contentsOf: opfURL)
        let opfDir = opfURL.deletingLastPathComponent()

        let parser = SimpleXMLParser(data: data)
        parser.parse()

        let title = parser.textContent["dc:title"] ?? parser.textContent["title"] ?? "Unknown Title"
        let author = parser.textContent["dc:creator"] ?? parser.textContent["creator"] ?? "Unknown Author"

        // Resolve spine items to file URLs
        let manifestItems = parser.manifestItems  // id -> href
        let spineIDs = parser.spineOrder          // ordered item ids

        let chapterURLs: [URL] = spineIDs.compactMap { id -> URL? in
            guard let href = manifestItems[id] else { return nil }
            let url = opfDir.appendingPathComponent(href)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        // Cover image
        var coverData: Data?
        if let coverId = parser.coverItemID ?? parser.metaCoverID,
           let coverHref = manifestItems[coverId] {
            let coverURL = opfDir.appendingPathComponent(coverHref)
            coverData = try? Data(contentsOf: coverURL)
        }

        // TOC: use spine order labels if no nav
        let toc = chapterURLs.enumerated().map { idx, url in
            TOCItem(label: "Chapter \(idx + 1)", chapterIndex: idx)
        }

        return EPUBMetadata(
            title: title,
            author: author,
            coverImageData: coverData,
            chapterURLs: chapterURLs,
            tableOfContents: toc
        )
    }
}

// MARK: - Minimal XML parser

private final class SimpleXMLParser: NSObject, XMLParserDelegate {

    private let data: Data
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    private var currentText = ""

    private(set) var textContent: [String: String] = [:]
    private(set) var attributes: [String: [String: String]] = [:]
    private(set) var manifestItems: [String: String] = [:]
    private(set) var spineOrder: [String] = []
    private(set) var coverItemID: String?
    private(set) var metaCoverID: String?

    init(data: Data) { self.data = data }

    func parse() {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
        currentElement = tag
        currentText = ""
        self.attributes[tag] = attributes

        switch tag {
        case "item":
            if let id = attributes["id"], let href = attributes["href"] {
                manifestItems[id] = href
                if attributes["properties"]?.contains("cover-image") == true {
                    coverItemID = id
                }
            }
        case "itemref":
            if let idref = attributes["idref"] {
                spineOrder.append(idref)
            }
        case "meta":
            if attributes["name"] == "cover", let content = attributes["content"] {
                metaCoverID = content
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        let tag = element.lowercased().components(separatedBy: ":").last ?? element.lowercased()
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            textContent[tag] = trimmed
            // Also store with namespace prefix for dc: elements
            textContent[element.lowercased()] = trimmed
        }
    }
}
