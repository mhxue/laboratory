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
                background: Color(hex: "#FFFFFF"),
                text: Color(hex: "#1A1A1A"),
                secondaryText: .secondary,
                chrome: Color(.systemBackground)
            )
        case .sepia:
            return AppTheme(
                background: Color(hex: "#F5EDD6"),
                text: Color(hex: "#3B2E1E"),
                secondaryText: Color(hex: "#6B5340"),
                chrome: Color(hex: "#EDE5C9")
            )
        case .dark:
            return AppTheme(
                background: Color(hex: "#161618"),
                text: Color(hex: "#E8E8ED"),
                secondaryText: Color(hex: "#98989F"),
                chrome: Color(hex: "#1C1C1E")
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

// MARK: - Color(hex:) extension

extension Color {
    /// Initialise a `Color` from a `"#RRGGBB"` or `"#RRGGBBAA"` hex string.
    /// Returns `.clear` for malformed input.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
