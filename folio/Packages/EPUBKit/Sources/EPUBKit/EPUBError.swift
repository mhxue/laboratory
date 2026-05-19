import Foundation

/// Errors produced by ``EPUBParser`` during parsing.
public enum EPUBError: LocalizedError, Sendable {
    case notAnEPUB
    case missingContainer
    case missingOPF
    case malformedOPF

    public var errorDescription: String? {
        switch self {
        case .notAnEPUB:         return "File is not a valid EPUB archive."
        case .missingContainer:  return "Missing META-INF/container.xml."
        case .missingOPF:        return "Could not locate OPF package document."
        case .malformedOPF:      return "OPF package document is malformed."
        }
    }
}
