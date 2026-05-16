import Foundation
import Observation
import EPUBKit

/// Concrete `@Observable` implementation of `SettingsViewModeling`.
///
/// Persists `EPUBStylesheet` settings across launches via `UserDefaults`.
@Observable
@MainActor
final class SettingsViewModel: SettingsViewModeling {

    // MARK: - SettingsViewModeling

    var stylesheet: EPUBStylesheet {
        didSet { persist() }
    }

    // MARK: - Init

    init() {
        stylesheet = SettingsViewModel.load()
    }

    // MARK: - Persistence

    private static let key = "folio.stylesheet"

    private static func load() -> EPUBStylesheet {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(StoredStylesheet.self, from: data) else {
            return .default
        }
        return EPUBStylesheet(
            fontSize: decoded.fontSize,
            lineSpacing: decoded.lineSpacing,
            theme: decoded.theme,
            font: decoded.font
        )
    }

    private func persist() {
        let stored = StoredStylesheet(
            fontSize: stylesheet.fontSize,
            lineSpacing: stylesheet.lineSpacing,
            theme: stylesheet.theme,
            font: stylesheet.font
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// Codable mirror (EPUBStylesheet itself is not Codable to stay pure)
private struct StoredStylesheet: Codable {
    var fontSize: Double
    var lineSpacing: Double
    var theme: EPUBTheme
    var font: EPUBFont
}
