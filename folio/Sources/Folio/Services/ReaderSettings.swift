import Foundation
import Observation

enum ReaderTheme: String, CaseIterable {
    case light, sepia, dark

    var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .sepia: return "#F5EEDD"
        case .dark: return "#1C1C1E"
        }
    }

    var textColor: String {
        switch self {
        case .light: return "#1C1C1E"
        case .sepia: return "#3B2E1E"
        case .dark: return "#E5E5EA"
        }
    }
}

enum ReaderFont: String, CaseIterable {
    case serif = "Georgia, serif"
    case sansSerif = "-apple-system, sans-serif"

    var displayName: String {
        switch self {
        case .serif: return "Serif"
        case .sansSerif: return "Sans-Serif"
        }
    }
}

@Observable
final class ReaderSettings {
    var fontSize: Double = 18
    var lineSpacing: Double = 1.6
    var theme: ReaderTheme = .light
    var font: ReaderFont = .serif

    var css: String {
        """
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: \(theme.backgroundColor);
            color: \(theme.textColor);
            font-family: \(font.rawValue);
            font-size: \(fontSize)px;
            line-height: \(lineSpacing);
            padding: 24px 20px 48px;
            max-width: 680px;
            margin: 0 auto;
            -webkit-text-size-adjust: none;
        }
        h1, h2, h3, h4 {
            margin: 1.2em 0 0.6em;
            line-height: 1.3;
        }
        p { margin-bottom: 0.9em; text-indent: 1.5em; }
        p:first-of-type { text-indent: 0; }
        img { max-width: 100%; height: auto; display: block; margin: 1em auto; }
        a { color: inherit; text-decoration: underline; }
        """
    }
}
