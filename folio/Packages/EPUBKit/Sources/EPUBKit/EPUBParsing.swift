import Foundation

/// Protocol for EPUB parsing. Implementations extract and parse an EPUB file
/// at the given URL into the extraction directory, returning a structured document.
public protocol EPUBParsing: Sendable {
    func parse(epubAt url: URL, extractingTo dir: URL) throws -> EPUBDocument
}
