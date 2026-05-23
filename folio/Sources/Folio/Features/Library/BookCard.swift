import SwiftUI

/// Book grid cell — cover + title + author + optional progress chip overlay.
///
/// Designed for the dark library grid in Folio v1. The cover image (or
/// placeholder) sits in a 2:3 aspect frame with a small drop shadow and
/// inset highlight, mirroring a real paperback spine.
struct BookCard: View {
    let book: Book
    let store: any BookStoring

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImage
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(alignment: .topTrailing) { progressChip }
                .overlay(spineHighlight)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)

            Text(book.title)
                .font(.system(size: 13, weight: .semibold))
                .kerning(-0.2)
                .lineLimit(2)
                .foregroundStyle(theme.text)

            Text(book.author)
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryText)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var progressChip: some View {
        if book.isInProgress {
            Text("\(Int(book.progressFraction * 100))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(8)
        } else if book.isFinished {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .padding(5)
                .background(theme.success, in: Circle())
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(8)
        }
    }

    /// Thin shaded stripe on the left edge — gives the cover a paperback feel.
    private var spineHighlight: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(width: 1)
                .padding(.leading, 3)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let image = store.coverImage(for: book) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    theme.accent.opacity(0.75),
                    theme.accent.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(book.author.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(12)
        }
    }
}
