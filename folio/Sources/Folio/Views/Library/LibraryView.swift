import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Book.addedDate, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var context
    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var importError: String?
    @State private var selectedBook: Book?

    private let store = BookStore()
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books) { book in
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
                SettingsView()
            }
            .navigationDestination(item: $selectedBook) { book in
                ReaderView(book: book, store: store)
            }
            .alert("Import Failed", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

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
            try? store.deleteBook(book, context: context)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                _ = try store.importBook(from: url, context: context)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

// Teach SwiftUI about our epub UTType
import UniformTypeIdentifiers
extension UTType {
    static let epub = UTType(importedAs: "org.idpf.epub-container")
}
