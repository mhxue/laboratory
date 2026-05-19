import SwiftUI
import EPUBKit

/// Converts an array of ``EPUBInline`` values into a SwiftUI `Text` view
/// by recursively composing inline styles using the `+` operator.
func inlineText(_ inlines: [EPUBInline], baseFont: Font, textColor: Color) -> Text {
    inlines.reduce(Text("")) { acc, inline in
        acc + inlineTextSingle(inline, baseFont: baseFont, textColor: textColor)
    }
}

private func inlineTextSingle(_ inline: EPUBInline, baseFont: Font, textColor: Color) -> Text {
    switch inline {
    case .text(let s):
        return Text(s).foregroundColor(textColor)

    case .emphasis(let inner):
        return inlineText(inner, baseFont: baseFont, textColor: textColor).italic()

    case .strong(let inner):
        return inlineText(inner, baseFont: baseFont, textColor: textColor).bold()

    case .smallCaps(let inner):
        return inlineText(inner, baseFont: baseFont, textColor: textColor).font(baseFont.smallCaps())

    case .lineBreak:
        return Text("\n")

    case .superscript(let inner):
        return inlineText(inner, baseFont: baseFont.smallCaps(), textColor: textColor)

    case .subscript(let inner):
        return inlineText(inner, baseFont: baseFont.smallCaps(), textColor: textColor)

    case .code(let inner):
        return inlineText(inner, baseFont: .system(size: 14, design: .monospaced), textColor: textColor)

    case .link(_, let inner):
        return inlineText(inner, baseFont: baseFont, textColor: .accentColor)

    case .strikethrough(let inner):
        return inlineText(inner, baseFont: baseFont, textColor: textColor).strikethrough()

    case .mark(let inner):
        return inlineText(inner, baseFont: baseFont, textColor: textColor)

    case .pageBreakMarker:
        return Text("")
    }
}
