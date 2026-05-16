import SwiftUI

struct BookCard: View {
    let book: Book
    let store: any BookStoring

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverImage
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            Text(book.title)
                .font(.caption.bold())
                .lineLimit(2)

            Text(book.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(value: book.progressFraction)
                .tint(.accentColor)
        }
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
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.6), Color.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            VStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                Text(book.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(3)
            }
        }
    }
}
