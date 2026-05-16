import SwiftUI
import EPUBKit

/// Named colour tokens for the app UI, derived from the active `EPUBTheme`
/// and the system colour scheme.
struct AppTheme {
    var background: Color
    var text: Color
    var secondaryText: Color
    var chrome: Color      // toolbar / chrome backgrounds

    // MARK: Factory

    static func from(_ epubTheme: EPUBTheme, _ colorScheme: ColorScheme) -> AppTheme {
        switch epubTheme {
        case .light:
            return AppTheme(
                background: .white,
                text: Color(red: 0.11, green: 0.11, blue: 0.12),
                secondaryText: .secondary,
                chrome: Color(.systemBackground)
            )
        case .sepia:
            return AppTheme(
                background: Color(red: 0.96, green: 0.94, blue: 0.87),
                text: Color(red: 0.23, green: 0.18, blue: 0.12),
                secondaryText: Color(red: 0.45, green: 0.35, blue: 0.25),
                chrome: Color(red: 0.94, green: 0.91, blue: 0.84)
            )
        case .dark:
            return AppTheme(
                background: Color(red: 0.11, green: 0.11, blue: 0.12),
                text: Color(red: 0.90, green: 0.90, blue: 0.92),
                secondaryText: Color(red: 0.60, green: 0.60, blue: 0.65),
                chrome: Color(red: 0.16, green: 0.16, blue: 0.18)
            )
        }
    }

    /// Convenience: derive theme ignoring colour scheme (uses `.light` system appearance).
    static func from(_ epubTheme: EPUBTheme) -> AppTheme {
        from(epubTheme, .light)
    }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.from(.light, .light)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
