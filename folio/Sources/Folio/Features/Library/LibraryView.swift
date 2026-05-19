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

    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var selectedBook: Book?

    private let store: any BookStoring

    init(viewModel: VM, store: any BookStoring) {
        self._viewModel = State(initialValue: viewModel)
        self.store = store
    }

    private var gridColumns: [GridItem] {
        let count = DeviceClass.current(horizontalSizeClass: sizeClass).libraryColumns
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        if sizeClass == .compact {
            NavigationStack { libraryContent }
        } else {
            NavigationSplitView {
                NavigationStack { libraryContent }
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
                if let book = selectedBook {
                    ReaderView(
                        viewModel: ReaderViewModel(book: book, store: store, context: context),
                        book: book,
                        store: store
                    )
                } else {
                    ContentUnavailableView("Select a Book", systemImage: "book.closed")
                }
            }
        }
    }

    // MARK: - Library content (no NavigationStack wrapper)

    private var libraryContent: some View {
        Group {
            if queriedBooks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(queriedBooks) { book in
                            BookCard(book: book, store: store)
                                .onTapGesture { selectedBook = book }
                                .contextMenu { deleteMenu(book) }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Folio")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingImporter = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.epub]) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: SettingsViewModel())
        }
        .navigationDestination(item: $selectedBook) { book in
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

    // MARK: - Private views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No books yet")
                .font(.title2.bold())
            Text("Tap + to import an EPUB file")
                .foregroundStyle(.secondary)
            Button("Import Book") { showingImporter = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
