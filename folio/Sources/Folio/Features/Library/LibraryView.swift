import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Teach SwiftUI about our epub UTType
extension UTType {
    static let epub = UTType(importedAs: "org.idpf.epub-container")
}

struct LibraryView<VM: LibraryViewModeling>: View {
    @State var viewModel: VM

    /// Books queried directly from SwiftData so the list stays live
    /// even when the VM refreshes from an external context change.
    @Query(sort: \Book.addedDate, order: .reverse) private var queriedBooks: [Book]
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

    @State private var showingImporter = false
    @State private var detailBook: Book?       // tapped from grid → book detail
    @State private var readerBook: Book?       // hero card or "Continue reading" CTA → reader

    private let store: any BookStoring

    init(viewModel: VM, store: any BookStoring) {
        self._viewModel = State(initialValue: viewModel)
        self.store = store
    }

    private var gridColumns: [GridItem] {
        let count = DeviceClass.current(horizontalSizeClass: sizeClass).libraryColumns
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    var body: some View {
        if sizeClass == .compact {
            NavigationStack { libraryContent }
        } else {
            NavigationSplitView {
                NavigationStack { libraryContent }
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
                if let book = readerBook {
                    ReaderView(
                        viewModel: ReaderViewModel(book: book, store: store, context: context),
                        book: book,
                        store: store
                    )
                } else if let book = detailBook {
                    BookDetailView(
                        viewModel: BookDetailViewModel(book: book),
                        store: store,
                        onContinue: { readerBook = book }
                    )
                } else {
                    ContentUnavailableView("Select a Book", systemImage: "book.closed")
                }
            }
        }
    }

    // MARK: - Library content (no NavigationStack wrapper)

    private var libraryContent: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if queriedBooks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        filterPills
                        if let hero = viewModel.continueReading, viewModel.filter == .all {
                            heroCard(hero)
                                .padding(.horizontal, 20)
                        }
                        if !viewModel.filteredBooks.isEmpty {
                            sectionLabel
                            grid
                        } else {
                            emptyFilterState
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingImporter = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.epub]) { result in
            handleImport(result)
        }
        .navigationDestination(item: $detailBook) { book in
            BookDetailView(
                viewModel: BookDetailViewModel(book: book),
                store: store,
                onContinue: { readerBook = book }
            )
        }
        .navigationDestination(item: $readerBook) { book in
            ReaderView(
                viewModel: ReaderViewModel(book: book, store: store, context: context),
                book: book,
                store: store
            )
        }
        .alert("Import Failed", isPresented: .constant(viewModel.importError != nil)) {
            Button("OK") { viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "")
        }
        .overlay {
            if viewModel.isImporting {
                ProgressView("Importing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Filter pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    let isOn = viewModel.filter == f
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { viewModel.filter = f }
                    } label: {
                        HStack(spacing: 6) {
                            Text(f.displayName)
                                .font(.system(size: 12.5, weight: .medium))
                            let count = viewModel.count(for: f)
                            if count > 0 {
                                Text("· \(count)")
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .opacity(0.7)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(isOn ? theme.text : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(isOn ? Color.clear : theme.border, lineWidth: 1)
                        )
                        .foregroundStyle(isOn ? theme.background : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero card

    @ViewBuilder
    private func heroCard(_ book: Book) -> some View {
        Button { readerBook = book } label: {
            HStack(spacing: 14) {
                miniCover(book)
                    .frame(width: 64, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel(text: "Continue reading", color: theme.accent)
                    Text(book.title)
                        .font(.system(size: 15, weight: .bold))
                        .kerning(-0.2)
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    progressBar(fraction: book.progressFraction)
                    Text("\(Int(book.progressFraction * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(theme.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func miniCover(_ book: Book) -> some View {
        if let img = store.coverImage(for: book) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.accent.opacity(0.7))
                .overlay(
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.white)
                )
        }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surface3)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .padding(.top, 4)
    }

    // MARK: - Section label

    private var sectionLabel: some View {
        HStack {
            MonoLabel(text: viewModel.filter == .all ? "Recently added" : viewModel.filter.displayName, color: theme.tertiaryText)
            Spacer()
            MonoLabel(text: "Newest ↓", color: theme.tertiaryText, tracking: 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: gridColumns, spacing: 22) {
            ForEach(viewModel.filteredBooks) { book in
                BookCard(book: book, store: store)
                    .onTapGesture { detailBook = book }
                    .contextMenu {
                        Button {
                            readerBook = book
                        } label: {
                            Label(book.progress != nil ? "Continue Reading" : "Read Now", systemImage: "book")
                        }
                        deleteMenu(book)
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundStyle(theme.tertiaryText)
            DisplayLabel(text: "Your library is yours.", size: 22, color: theme.text)
            Text("Books stay on your device.\nNo accounts, no cloud, no expiry.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            Button("Import EPUB") { showingImporter = true }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var emptyFilterState: some View {
        VStack(spacing: 8) {
            MonoLabel(text: "Nothing here yet", color: theme.tertiaryText)
            Text("No books match \"\(viewModel.filter.displayName)\".")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func deleteMenu(_ book: Book) -> some View {
        Button(role: .destructive) {
            Task { await viewModel.deleteBook(book) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            Task { await viewModel.importBook(from: url) }
        case .failure(let error):
            viewModel.importError = error.localizedDescription
        }
    }
}
