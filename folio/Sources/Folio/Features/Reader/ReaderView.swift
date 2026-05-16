import SwiftUI
import SwiftData
import EPUBKit

struct ReaderView<VM: ReaderViewModeling>: View {
    @State var viewModel: VM
    let book: Book
    let store: any BookStoring

    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showTOC = false
    @State private var showSettingsSheet = false

    init(viewModel: VM, book: Book, store: any BookStoring) {
        self._viewModel = State(initialValue: viewModel)
        self.book = book
        self.store = store
    }

    private var stylesheet: EPUBStylesheet { settingsVM.stylesheet }

    private var themeBackground: Color {
        Color(hex: stylesheet.theme.backgroundColor)
    }

    var body: some View {
        ZStack {
            themeBackground.ignoresSafeArea()

            if viewModel.isLoading || viewModel.chapterURLs.isEmpty {
                ProgressView("Opening book…")
            } else {
                readerContent
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!viewModel.showChrome)
        .task { await viewModel.load() }
        .onDisappear { viewModel.saveProgress() }
        .sheet(isPresented: $showTOC) { tocSheet }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(viewModel: settingsVM)
        }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        ZStack {
            // Full-screen paged chapter view — tap zones handled inside via JS
            paginatedChapterView
                .ignoresSafeArea()

            // Chrome bars (auto-hiding)
            VStack {
                if viewModel.showChrome {
                    topChrome
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if viewModel.showChrome {
                    bottomChrome
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Paginated chapter view

    private var paginatedChapterView: some View {
        Group {
            if viewModel.currentChapterIndex < viewModel.chapterURLs.count {
                let url = viewModel.chapterURLs[viewModel.currentChapterIndex]
                ChapterWebView(
                    url: url,
                    stylesheet: stylesheet,
                    initialPage: viewModel.currentPage,
                    onReady: { pageCount in
                        viewModel.totalPages = pageCount
                    },
                    onPageChanged: { page in
                        viewModel.currentPage = page
                    },
                    onOverscrollForward: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.advanceChapter()
                        }
                    },
                    onOverscrollBackward: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.retreatChapter()
                        }
                    },
                    onTap: { zone in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            switch zone {
                            case "left":  goBackward()
                            case "right": goForward()
                            default:      viewModel.showChrome.toggle()
                            }
                        }
                    }
                )
                .id(viewModel.currentChapterIndex)
            }
        }
    }

    private func goForward() {
        if viewModel.currentPage < viewModel.totalPages - 1 {
            viewModel.currentPage += 1
        } else {
            viewModel.advanceChapter()
        }
    }

    private func goBackward() {
        if viewModel.currentPage > 0 {
            viewModel.currentPage -= 1
        } else {
            viewModel.retreatChapter()
        }
    }

    // MARK: - Chrome bars

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            Text(chapterTitle)
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Menu {
                Button { showTOC = true } label: {
                    Label("Contents", systemImage: "list.bullet")
                }
                Button { viewModel.addBookmark(note: "") } label: {
                    Label("Add Bookmark", systemImage: "bookmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            themeBackground
                .opacity(0.4)
                .background(.ultraThinMaterial)
        )
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            // Page label + progress bar
            HStack {
                Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.currentPage + 1), total: Double(max(viewModel.totalPages, 1)))
                .tint(.accentColor)
                .padding(.horizontal)

            // Icon row
            HStack(spacing: 32) {
                Button { showSettingsSheet = true } label: {
                    Image(systemName: "textformat.size")
                }
                Spacer()
                Button { showTOC = true } label: {
                    Image(systemName: "list.bullet")
                }
                Button {
                    viewModel.addBookmark(note: "")
                } label: {
                    Image(systemName: "bookmark")
                }
            }
            .font(.title3)
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .background(
            themeBackground
                .opacity(0.4)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Helpers

    private var chapterTitle: String {
        let idx = viewModel.currentChapterIndex
        if viewModel.chapterURLs.count > 1 {
            return "Chapter \(idx + 1) of \(viewModel.chapterURLs.count)"
        }
        return book.title
    }

    // MARK: - TOC sheet

    private var tocSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapterURLs.enumerated()), id: \.offset) { index, _ in
                    Button {
                        viewModel.currentChapterIndex = index
                        viewModel.currentPage = 0
                        showTOC = false
                    } label: {
                        HStack {
                            Text("Chapter \(index + 1)")
                            Spacer()
                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Contents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTOC = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
