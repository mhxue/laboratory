import Foundation

/// Reader theme controlling background and text colours.
public enum EPUBTheme: String, CaseIterable, Codable, Sendable {
    case light
    case sepia
    case dark

    public var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .sepia: return "#F5EDD6"
        case .dark:  return "#161618"
        }
    }

    public var textColor: String {
        switch self {
        case .light: return "#1A1A1A"
        case .sepia: return "#3B2E1E"
        case .dark:  return "#E8E8ED"
        }
    }

    public var linkColor: String {
        switch self {
        case .light: return "#E6591B"
        case .sepia: return "#A0522D"
        case .dark:  return "#FF9F5B"
        }
    }
}

/// Reader font family.
public enum EPUBFont: String, CaseIterable, Codable, Sendable {
    case serif
    case sansSerif

    var cssValue: String {
        switch self {
        case .serif:     return "Georgia, 'Times New Roman', serif"
        case .sansSerif: return "-apple-system, 'Helvetica Neue', sans-serif"
        }
    }

    public var displayName: String {
        switch self {
        case .serif:     return "Serif"
        case .sansSerif: return "Sans-Serif"
        }
    }
}

/// Horizontal margin preset that controls the body's left/right padding.
///
/// Maps directly to the CSS `padding-left`/`padding-right` emitted in
/// `EPUBStylesheet.css`. The numeric values are deliberately conservative
/// so even on compact iPhones the longest preset still leaves room for ~6
/// characters of breathing space at the edges.
public enum EPUBMargin: String, CaseIterable, Codable, Sendable {
    case tight
    case comfortable
    case wide

    public var horizontalPadding: Double {
        switch self {
        case .tight:        return 16
        case .comfortable:  return 28
        case .wide:         return 44
        }
    }

    public var displayName: String {
        switch self {
        case .tight:        return "Tight"
        case .comfortable:  return "Comfortable"
        case .wide:         return "Wide"
        }
    }
}

/// Value type encapsulating all typography and appearance settings for the reader.
/// Generates a complete CSS string that is injected into each chapter's web view.
public struct EPUBStylesheet: Equatable, Sendable {
    public var fontSize: Double       // default 18
    public var lineSpacing: Double    // default 1.6
    public var theme: EPUBTheme       // .light / .sepia / .dark
    public var font: EPUBFont         // .serif / .sansSerif
    public var margin: EPUBMargin     // .tight / .comfortable / .wide

    public init(fontSize: Double = 18,
                lineSpacing: Double = 1.6,
                theme: EPUBTheme = .light,
                font: EPUBFont = .serif,
                margin: EPUBMargin = .comfortable) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.theme = theme
        self.font = font
        self.margin = margin
    }

    public static let `default` = EPUBStylesheet()

    /// Full CSS string suitable for injection via a `<style>` tag.
    /// Designed for CSS column pagination: content flows horizontally into pages.
    public var css: String {
        """
        * { box-sizing: border-box; }
        html, body {
            height: 100%;
            margin: 0;
            padding: 0;
            overflow: hidden;
        }
        body {
            background-color: \(theme.backgroundColor);
            color: \(theme.textColor);
            font-family: \(font.cssValue);
            font-size: \(fontSize)px;
            line-height: \(lineSpacing);
            padding: 56px \(margin.horizontalPadding)px 72px;
            overflow-x: scroll;
            overflow-y: hidden;
            column-fill: auto;
            -webkit-hyphens: auto;
            hyphens: auto;
            word-break: break-word;
            -webkit-text-size-adjust: none;
        }
        h1, h2, h3, h4 {
            margin: 1.2em 0 0.6em;
            line-height: 1.3;
            text-indent: 0;
        }
        p {
            margin: 0;
            text-indent: 1.4em;
        }
        h1 + p, h2 + p, h3 + p, h4 + p,
        p:first-of-type {
            text-indent: 0;
        }
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 1em auto;
            page-break-inside: avoid;
        }
        a {
            color: \(theme.linkColor);
            text-decoration: underline;
        }
        """
    }
}
