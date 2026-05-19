import Foundation

/// Parses an XHTML chapter file into an ``EPUBContent`` AST.
/// XHTML is treated as valid XML — no HTML parser is used.
public protocol EPUBContentParsing: Sendable {
    func parse(xhtmlAt url: URL) throws -> EPUBContent
}
