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
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showTOC = false
    @State private var showSettingsSheet = false
    @State private var engine = NativeReaderEngine()
    @State private var goToLastPage = false
    @FocusState private var isFocused: Bool

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
            // Full-screen paged chapter view
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
        .focusable()
        .focused($isFocused)
        .onKeyPress(.leftArrow)  { goBackward(); return .handled }
        .onKeyPress(.rightArrow) { goForward();  return .handled }
        .onKeyPress(.space)      { goForward();  return .handled }
        .onAppear { isFocused = true }
    }

    // MARK: - Paginated chapter view (native block renderer)

    private var paginatedChapterView: some View {
        GeometryReader { geo in
            let pageSize = geo.size
            Group {
                if engine.isReady && !engine.pages.isEmpty {
                    nativePagedView(pageSize: pageSize)
                } else if viewModel.currentChapterIndex < viewModel.chapterURLs.count {
                    // Show a spinner while engine is loading
                    Color(hex: stylesheet.theme.backgroundColor)
                        .overlay(ProgressView())
                }
            }
            .onChange(of: viewModel.currentChapterIndex) { _, _ in
                loadCurrentChapter(pageSize: pageSize)
            }
            .onChange(of: stylesheet) { _, _ in
                loadCurrentChapter(pageSize: pageSize)
            }
            .onChange(of: engine.isReady) { _, ready in
                guard ready, goToLastPage else { return }
                goToLastPage = false
                viewModel.currentPage = max(0, engine.pages.count - 1)
            }
            .task(id: "\(viewModel.currentChapterIndex)-\(pageSize.width)-\(pageSize.height)") {
                loadCurrentChapter(pageSize: pageSize)
            }
        }
    }

    private func loadCurrentChapter(pageSize: CGSize) {
        guard viewModel.currentChapterIndex < viewModel.chapterURLs.count else { return }
        let url = viewModel.chapterURLs[viewModel.currentChapterIndex]
        let dc = DeviceClass.current(horizontalSizeClass: sizeClass)
        engine.load(chapterURL: url, stylesheet: stylesheet, pageSize: pageSize, deviceClass: dc)
        if !goToLastPage {
            viewModel.currentPage = 0
        }
    }

    private func nativePagedView(pageSize: CGSize) -> some View {
        // Snapshot both arrays so the view captures stable values at render time.
        // engine.pages/blocks can be reset to [] on the main actor while
        // SwiftUI is still diffing the previous render — reading live inside the
        // view builder would cause index-out-of-bounds crashes.
        let pages  = engine.pages
        let blocks = engine.blocks
        let dc     = DeviceClass.current(horizontalSizeClass: sizeClass)

        return BookPageTurnView(
            pages: pages,
            blocks: blocks,
            stylesheet: stylesheet,
            deviceClass: dc,
            currentIndex: $viewModel.currentPage,
            canAdvanceChapter: viewModel.currentChapterIndex < viewModel.chapterURLs.count - 1,
            canRetreatChapter: viewModel.currentChapterIndex > 0,
            onAdvance:   { goForward() },
            onRetreat:   { goBackward() },
            onTapCenter: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showChrome.toggle()
                }
            }
        )
        .onAppear { viewModel.totalPages = pages.count }
        .onChange(of: pages.count) { _, count in viewModel.totalPages = count }
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
            goToLastPage = true
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
