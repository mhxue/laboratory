import SwiftUI
import EPUBKit

/// Dispatches rendering of a single ``EPUBBlock`` to the appropriate view.
struct EPUBBlockView: View {
    let block: EPUBBlock
    let stylesheet: EPUBStylesheet

    var body: some View {
        switch block {
        case .paragraph(let inlines, let style):
            ParagraphView(inlines: inlines, style: style, stylesheet: stylesheet)

        case .heading(let level, let inlines):
            HeadingView(level: level, inlines: inlines, stylesheet: stylesheet)

        case .blockquote(let blocks):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(blocks.indices, id: \.self) { i in
                    EPUBBlockView(block: blocks[i], stylesheet: stylesheet)
                }
            }
            .padding(.leading, CGFloat(stylesheet.fontSize) * 2)
            .padding(.trailing, CGFloat(stylesheet.fontSize))

        case .image(let src, let alt):
            // Async image load using the src URL — falls back to a placeholder.
            AsyncImage(url: URL(string: src)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                case .failure:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 200)
                        .overlay(
                            Text(alt ?? "Image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        )
                case .empty:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 200)
                @unknown default:
                    EmptyView()
                }
            }
            .padding(.vertical, 8)

        case .divider:
            Divider()
                .frame(height: 1)
                .background(Color.secondary.opacity(0.4))
                .padding(.vertical, 8)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inlineText(items[i].inlines, stylesheet: stylesheet)
                    }
                    ForEach(items[i].children.indices, id: \.self) { j in
                        EPUBBlockView(block: items[i].children[j], stylesheet: stylesheet)
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 4)

        case .orderedList(let items, let start):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(start + i).").foregroundStyle(.secondary)
                        inlineText(items[i].inlines, stylesheet: stylesheet)
                    }
                    ForEach(items[i].children.indices, id: \.self) { j in
                        EPUBBlockView(block: items[i].children[j], stylesheet: stylesheet)
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 4)

        case .definitionList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { i in
                    ForEach(items[i].terms.indices, id: \.self) { j in
                        inlineText(items[i].terms[j], stylesheet: stylesheet).bold()
                    }
                    ForEach(items[i].definitions.indices, id: \.self) { j in
                        inlineText(items[i].definitions[j], stylesheet: stylesheet)
                            .padding(.leading, 24)
                    }
                }
            }
            .padding(.vertical, 4)

        case .table(let table):
            VStack(alignment: .leading, spacing: 2) {
                if let caption = table.caption {
                    inlineText(caption, stylesheet: stylesheet)
                        .font(.caption.bold())
                        .padding(.bottom, 4)
                }
                ForEach(table.head.indices, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(table.head[r].indices, id: \.self) { c in
                            inlineText(table.head[r][c].inlines, stylesheet: stylesheet)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
                ForEach(table.body.indices, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(table.body[r].indices, id: \.self) { c in
                            inlineText(table.body[r][c].inlines, stylesheet: stylesheet)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)

        case .preformatted(let inlines):
            inlineText(inlines, stylesheet: stylesheet)
                .font(.system(size: CGFloat(stylesheet.fontSize) * 0.9, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.vertical, 4)

        case .figure(let image, let caption):
            VStack(spacing: 4) {
                AsyncImage(url: URL(string: image.src)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().frame(maxWidth: .infinity)
                    default:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 180)
                            .overlay(Text(image.alt ?? "").font(.caption).foregroundStyle(.secondary))
                    }
                }
                if let cap = caption {
                    inlineText(cap, stylesheet: stylesheet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, 8)

        case .section(_, let blocks):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(blocks.indices, id: \.self) { i in
                    EPUBBlockView(block: blocks[i], stylesheet: stylesheet)
                }
            }

        case .footnote(_, let blocks):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(blocks.indices, id: \.self) { i in
                    EPUBBlockView(block: blocks[i], stylesheet: stylesheet)
                }
            }
            .padding(.leading, 8)
            .overlay(Rectangle().frame(width: 2).foregroundStyle(.secondary.opacity(0.4)), alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func inlineText(_ inlines: [EPUBInline], stylesheet: EPUBStylesheet) -> Text {
        let size = CGFloat(stylesheet.fontSize)
        let fontName = stylesheet.font == .serif ? "Georgia" : nil
        let base: Font = fontName.map { .custom($0, size: size) } ?? .system(size: size)
        let color = Color(hex: stylesheet.theme.textColor)
        return Folio.inlineText(inlines, baseFont: base, textColor: color)
    }
}
