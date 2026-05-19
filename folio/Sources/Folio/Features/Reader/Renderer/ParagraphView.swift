import SwiftUI
import EPUBKit

/// Renders a single paragraph block, applying font, colour, line spacing,
/// and optional first-line em-space indent.
struct ParagraphView: View {
    let inlines: [EPUBInline]
    let style: EPUBParagraphStyle
    let stylesheet: EPUBStylesheet

    var body: some View {
        let fontName = stylesheet.font == .serif ? "Georgia" : nil
        let font: Font = fontName.flatMap { Font.custom($0, size: stylesheet.fontSize) }
            ?? .system(size: stylesheet.fontSize)
        let textColor = Color(hex: stylesheet.theme.textColor)
        let lineSpacingValue = CGFloat((stylesheet.lineSpacing - 1.0) * stylesheet.fontSize)

        Group {
            if style.noIndent || style.centered {
                inlineText(inlines, baseFont: font, textColor: textColor)
                    .font(font)
                    .foregroundColor(textColor)
                    .lineSpacing(lineSpacingValue)
                    .multilineTextAlignment(style.centered ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: style.centered ? .center : .leading)
                    .padding(.bottom, 12)
            } else {
                // First-line indent via em-space prefix
                (Text("\u{2003}") + inlineText(inlines, baseFont: font, textColor: textColor))
                    .font(font)
                    .foregroundColor(textColor)
                    .lineSpacing(lineSpacingValue)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
            }
        }
    }
}

