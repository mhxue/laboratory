import SwiftUI
import EPUBKit

/// Renders a heading block with scaled font size and bold weight.
struct HeadingView: View {
    let level: Int
    let inlines: [EPUBInline]
    let stylesheet: EPUBStylesheet

    var body: some View {
        let multiplier: Double
        switch level {
        case 1: multiplier = 1.5
        case 2: multiplier = 1.3
        case 3: multiplier = 1.1
        default: multiplier = 1.0
        }
        let fontSize = stylesheet.fontSize * multiplier
        let fontName = stylesheet.font == .serif ? "Georgia" : nil
        let font: Font = fontName.flatMap { Font.custom($0, size: fontSize).bold() }
            ?? .system(size: fontSize, weight: .bold)
        let textColor = Color(hex: stylesheet.theme.textColor)

        return inlineText(inlines, baseFont: font, textColor: textColor)
            .font(font)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}
