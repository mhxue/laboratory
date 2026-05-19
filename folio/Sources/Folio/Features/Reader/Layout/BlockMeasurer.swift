import UIKit
import EPUBKit

/// Synchronously measures the rendered height of each ``EPUBBlock``.
///
/// Uses `NSString.boundingRect` — fast, no layout pass needed.
/// Lives in the app layer so EPUBKit remains UIKit-free.
struct BlockMeasurer: Sendable {
    let pageWidth: CGFloat
    let stylesheet: EPUBStylesheet
    let deviceClass: DeviceClass
    /// Extra spacing appended below each paragraph/heading block.
    let paragraphSpacing: CGFloat = 12

    init(pageWidth: CGFloat, stylesheet: EPUBStylesheet, deviceClass: DeviceClass = .compact) {
        self.pageWidth = pageWidth
        self.stylesheet = stylesheet
        self.deviceClass = deviceClass
    }

    // MARK: - Public API

    /// Returns the rendered height in points for a single block.
    func height(of block: EPUBBlock) -> CGFloat {
        switch block {
        case .paragraph(let inlines, let style):
            return paragraphHeight(inlines: inlines, style: style)

        case .heading(let level, let inlines):
            return headingHeight(level: level, inlines: inlines)

        case .blockquote(let blocks):
            let inner = blocks.reduce(0) { $0 + height(of: $1) }
            return inner + paragraphSpacing

        case .image:
            return 208   // 200 image + 8 padding

        case .figure(let img, let caption):
            let capHeight = caption.map { paragraphHeight(inlines: $0, style: .body) } ?? 0
            return 208 + capHeight

        case .divider:
            return 17

        case .unorderedList(let items), .orderedList(let items, _):
            return items.reduce(0) { acc, item in
                let textH = paragraphHeight(inlines: item.inlines, style: .body)
                let childH = item.children.reduce(0) { $0 + height(of: $1) }
                return acc + textH + childH
            } + paragraphSpacing

        case .definitionList(let items):
            return items.reduce(0) { acc, item in
                let termH = item.terms.reduce(0) { $0 + paragraphHeight(inlines: $1, style: .body) }
                let defH  = item.definitions.reduce(0) { $0 + paragraphHeight(inlines: $1, style: .body) }
                return acc + termH + defH + 6
            }

        case .table(let table):
            let rowCount = table.head.count + table.body.count
            return CGFloat(rowCount) * (CGFloat(stylesheet.fontSize) * stylesheet.lineSpacing + 2) + paragraphSpacing

        case .preformatted(let inlines):
            let text = EPUBContent.plainText(of: inlines) as NSString
            guard text.length > 0 else { return paragraphSpacing }
            let monoFont = UIFont.monospacedSystemFont(ofSize: CGFloat(stylesheet.fontSize) * 0.9, weight: .regular)
            let rect = text.boundingRect(
                with: CGSize(width: contentWidth - 16, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: monoFont],
                context: nil
            )
            return ceil(rect.height) + 16 + paragraphSpacing

        case .section(_, let blocks), .footnote(_, let blocks):
            return blocks.reduce(0) { $0 + height(of: $1) }
        }
    }

    // MARK: - Private helpers

    private var horizontalPadding: CGFloat { deviceClass.readerHorizontalPadding }

    private var contentWidth: CGFloat {
        let available = pageWidth - horizontalPadding * 2
        let maxW = deviceClass.readerContentMaxWidth
        return maxW == .infinity ? available : min(available, maxW)
    }

    private var baseFont: UIFont {
        let size = CGFloat(stylesheet.fontSize)
        if stylesheet.font == .serif {
            return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size)
        } else {
            return UIFont.systemFont(ofSize: size)
        }
    }

    private func paragraphHeight(inlines: [EPUBInline], style: EPUBParagraphStyle) -> CGFloat {
        let text = EPUBContent.plainText(of: inlines) as NSString
        guard text.length > 0 else { return paragraphSpacing }

        let font = baseFont
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = CGFloat((stylesheet.lineSpacing - 1.0) * stylesheet.fontSize)
        ps.alignment = style.centered ? .center : .natural
        if !style.noIndent && !style.centered {
            ps.firstLineHeadIndent = CGFloat(stylesheet.fontSize) * 1.5
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: ps
        ]

        let boundingRect = text.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(boundingRect.height) + paragraphSpacing
    }

    private func headingHeight(level: Int, inlines: [EPUBInline]) -> CGFloat {
        let multiplier: CGFloat
        switch level {
        case 1: multiplier = 1.5
        case 2: multiplier = 1.3
        case 3: multiplier = 1.1
        default: multiplier = 1.0
        }
        let fontSize = CGFloat(stylesheet.fontSize) * multiplier
        let headingFont: UIFont
        if stylesheet.font == .serif {
            let base = UIFont(name: "Georgia", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor
            headingFont = UIFont(descriptor: descriptor, size: fontSize)
        } else {
            headingFont = UIFont.boldSystemFont(ofSize: fontSize)
        }

        let text = EPUBContent.plainText(of: inlines) as NSString
        guard text.length > 0 else { return paragraphSpacing }

        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = CGFloat((stylesheet.lineSpacing - 1.0) * stylesheet.fontSize * Double(multiplier))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .paragraphStyle: ps
        ]

        let boundingRect = text.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        // Extra top margin for headings (16pt from spec)
        return ceil(boundingRect.height) + paragraphSpacing + 16
    }
}
