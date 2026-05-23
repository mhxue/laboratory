import SwiftUI
import EPUBKit

/// Named colour tokens for the app UI, derived from the active `EPUBTheme`
/// and the system colour scheme.
///
/// The token set follows the "Folio Design v1" — modern & sharp, dark-first.
/// Every surface from page background up to elevated dialogs has a token, so
/// downstream views never reach for raw hex.
struct AppTheme: Equatable {
    // Page-level backgrounds
    var background: Color          // root scrollable background
    var surface1: Color            // cards, hero blocks
    var surface2: Color            // sheets, raised buttons
    var surface3: Color            // tertiary fills, slider tracks
    var chrome: Color              // nav/tab bar backgrounds

    // Borders & dividers
    var border: Color              // 1px hairlines
    var borderStrong: Color        // 1px elevated surfaces

    // Text
    var text: Color                // primary content
    var secondaryText: Color       // captions, footnotes
    var tertiaryText: Color        // metadata, monospace labels

    // Brand / accent
    var accent: Color              // amber — ties to EPUBTheme.dark linkColor
    var accentSoft: Color          // accent at low alpha — highlight bg

    // Semantic
    var success: Color             // green highlight
    var warning: Color             // yellow highlight

    // MARK: Factory

    static func from(_ epubTheme: EPUBTheme, _ colorScheme: ColorScheme) -> AppTheme {
        switch epubTheme {
        case .light:
            return AppTheme(
                background:     Color(hex: "#FFFFFF"),
                surface1:       Color(hex: "#F7F7F8"),
                surface2:       Color(hex: "#EFEFF1"),
                surface3:       Color(hex: "#E5E5E8"),
                chrome:         Color(.systemBackground),
                border:         Color(hex: "#E0E0E2"),
                borderStrong:   Color(hex: "#C9C9CD"),
                text:           Color(hex: "#1A1A1A"),
                secondaryText:  .secondary,
                tertiaryText:   Color(hex: "#6E6E78"),
                accent:         Color(hex: "#E6591B"),
                accentSoft:     Color(hex: "#E6591B").opacity(0.12),
                success:        Color(hex: "#2EA66B"),
                warning:        Color(hex: "#C58A1A")
            )
        case .sepia:
            return AppTheme(
                background:     Color(hex: "#F5EDD6"),
                surface1:       Color(hex: "#EFE6CB"),
                surface2:       Color(hex: "#E8DEBE"),
                surface3:       Color(hex: "#DCCFA6"),
                chrome:         Color(hex: "#EDE5C9"),
                border:         Color(hex: "#D7CBA8"),
                borderStrong:   Color(hex: "#B7A77E"),
                text:           Color(hex: "#3B2E1E"),
                secondaryText:  Color(hex: "#6B5340"),
                tertiaryText:   Color(hex: "#8A7257"),
                accent:         Color(hex: "#A0522D"),
                accentSoft:     Color(hex: "#A0522D").opacity(0.14),
                success:        Color(hex: "#5C7A3C"),
                warning:        Color(hex: "#A07A2E")
            )
        case .dark:
            return AppTheme(
                background:     Color(hex: "#0A0A0B"),
                surface1:       Color(hex: "#131316"),
                surface2:       Color(hex: "#1C1C20"),
                surface3:       Color(hex: "#25252B"),
                chrome:         Color(hex: "#1C1C1E"),
                border:         Color(hex: "#2A2A30"),
                borderStrong:   Color(hex: "#3A3A42"),
                text:           Color(hex: "#F5F5F7"),
                secondaryText:  Color(hex: "#98989F"),
                tertiaryText:   Color(hex: "#6E6E78"),
                accent:         Color(hex: "#FF9F5B"),
                accentSoft:     Color(hex: "#FF9F5B").opacity(0.14),
                success:        Color(hex: "#6EE7A7"),
                warning:        Color(hex: "#F5C26B")
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
    static let defaultValue = AppTheme.from(.dark, .dark)
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
