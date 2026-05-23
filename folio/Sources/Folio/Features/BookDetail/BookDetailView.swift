import SwiftUI

/// Book detail screen — surface ownership story (file size, "Yours forever"),
/// chapter list, and a "Continue reading" CTA.
struct BookDetailView<VM: BookDetailViewModeling>: View {
    @State var viewModel: VM
    let store: any BookStoring
    var onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showShare = false

    init(viewModel: VM, store: any BookStoring, onContinue: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.store = store
        self.onContinue = onContinue
    }

    private var book: Book { viewModel.book }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailCard
                        .padding(.horizontal, 22)
                    ownershipCard
                        .padding(.horizontal, 22)
                    ctaRow
                        .padding(.horizontal, 22)
                    chapterList
                        .padding(.horizontal, 22)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Book details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.exportURL() != nil {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = viewModel.exportURL() {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Pieces

    private var detailCard: some View {
        HStack(alignment: .bottom, spacing: 16) {
            cover
                .frame(width: 120, height: 178)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 19, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(theme.text)
                    .lineLimit(3)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryText)
                MonoLabel(
                    text: "\(book.chapterCount) CH · \(viewModel.fileSizeFormatted)",
                    color: theme.tertiaryText
                )
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let image = store.coverImage(for: book) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 12)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [theme.accent.opacity(0.75), theme.accent.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                        Spacer()
                        Text(book.author.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(14),
                    alignment: .topLeading
                )
        }
    }

    private var ownershipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16, weight: .semibold))
                .padding(8)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(Color.black.opacity(0.85))
            VStack(alignment: .leading, spacing: 2) {
                Text("Yours forever")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(-0.1)
                    .foregroundStyle(theme.text)
                Text(ownershipBody)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(theme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var ownershipBody: String {
        viewModel.isStoredLocally
        ? "Stored on this device only. No account, no sync, no licence check."
        : "Local file is missing — re-import to restore."
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            Button(action: onContinue) {
                Text(book.progress != nil ? "Continue reading · \(Int(book.progressFraction * 100))%" : "Start reading")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(-0.1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.text, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(theme.background)
            }
            .buttonStyle(.plain)
        }
    }

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonoLabel(text: "Chapters", color: theme.tertiaryText)
                Spacer()
                MonoLabel(text: "\(book.chapterCount) total", color: theme.tertiaryText)
            }
            .padding(.bottom, 8)
            ForEach(viewModel.chapters) { entry in
                HStack(spacing: 12) {
                    Text(String(format: "%02d", entry.id + 1))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(entry.isCurrent ? theme.accent : theme.tertiaryText)
                        .frame(minWidth: 22, alignment: .leading)
                    Text(entry.title)
                        .font(.system(size: 12.5, weight: .regular, design: .serif))
                        .foregroundStyle(entry.isCurrent ? theme.accent : entry.isRead ? theme.tertiaryText : theme.text)
                    Spacer()
                    if let m = entry.estimatedMinutes {
                        Text("\(m) MIN")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }
                .padding(.vertical, 11)
                Divider().overlay(theme.border)
            }
        }
    }
}

/// Lightweight UIActivityViewController bridge — used by the "Export EPUB" toolbar action.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
