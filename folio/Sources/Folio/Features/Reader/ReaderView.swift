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
    @Environment(\.appTheme) private var appTheme

    @State private var showTOC = false
    @State private var showTypographySheet = false
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

    private var readerPalette: AppTheme {
        AppTheme.from(stylesheet.theme, colorScheme)
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
        .task {
            await viewModel.load()
            viewModel.revealChromeAndScheduleHide()
        }
        .onDisappear {
            viewModel.cancelChromeAutoHide()
            viewModel.saveProgress()
        }
        .sheet(isPresented: $showTOC) { tocSheet }
        .sheet(isPresented: $showTypographySheet) {
            SettingsView(viewModel: settingsVM, presentedAsSheet: true)
        }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        ZStack {
            paginatedChapterView
                .ignoresSafeArea()
                .opacity(viewModel.showChrome ? 0.55 : 1.0)
                .animation(.easeOut(duration: 0.18), value: viewModel.showChrome)

            // Chrome bars (auto-hiding)
            VStack(spacing: 0) {
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
            .animation(.easeOut(duration: 0.18), value: viewModel.showChrome)
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
            onTapCenter: { viewModel.toggleChrome() }
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
        HStack(spacing: 12) {
            iconButton(systemName: "chevron.left") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                MonoLabel(text: chapterCounter, color: readerPalette.accent, tracking: 1.4)
                Text(chapterTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .kerning(-0.1)
                    .foregroundStyle(readerPalette.text)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button { showTOC = true } label: { Label("Contents", systemImage: "list.bullet") }
                Button { viewModel.addBookmark(note: "", kind: .important) }
                    label: { Label("Highlight (Important)", systemImage: "bookmark") }
                Button { viewModel.addBookmark(note: "", kind: .connection) }
                    label: { Label("Highlight (Connection)", systemImage: "link") }
                Button { viewModel.addBookmark(note: "", kind: .lookup) }
                    label: { Label("Highlight (Look up later)", systemImage: "questionmark.circle") }
            } label: {
                iconLook(systemName: "ellipsis")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 50)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    themeBackground.opacity(0.95),
                    themeBackground.opacity(0.7),
                    themeBackground.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bottomChrome: some View {
        VStack(spacing: 12) {
            if let label = viewModel.timeLeftLabel {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(readerPalette.tertiaryText)
            }
            scrubber
            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [
                    themeBackground.opacity(0),
                    themeBackground.opacity(0.7),
                    themeBackground.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var scrubber: some View {
        HStack(spacing: 10) {
            Text("\(Int(viewModel.overallProgress * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(readerPalette.secondaryText)
                .frame(minWidth: 40, alignment: .leading)

            Slider(
                value: Binding(
                    get: { viewModel.overallProgress },
                    set: { viewModel.setOverallProgress($0) }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        viewModel.cancelChromeAutoHide()
                    } else {
                        viewModel.revealChromeAndScheduleHide()
                    }
                }
            )
            .tint(readerPalette.accent)

            Text("\(viewModel.chapterURLs.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(readerPalette.secondaryText)
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 28) {
            chromeAction(icon: "list.bullet", label: "TOC") { showTOC = true }
            chromeAction(icon: "textformat.size", label: "Type") { showTypographySheet = true }
            chromeAction(icon: "bookmark", label: "Mark") {
                viewModel.addBookmark(note: "", kind: .important)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chromeAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                MonoLabel(text: label, color: readerPalette.secondaryText, size: 8.5, tracking: 1.0)
            }
            .foregroundStyle(readerPalette.text)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { iconLook(systemName: systemName) }
            .buttonStyle(.plain)
    }

    private func iconLook(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 32, height: 32)
            .background(readerPalette.surface2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(readerPalette.border, lineWidth: 1)
            )
            .foregroundStyle(readerPalette.text)
    }

    // MARK: - Helpers

    private var chapterCounter: String {
        let idx = viewModel.currentChapterIndex
        let total = viewModel.chapterURLs.count
        return total > 0 ? "Chapter \(idx + 1) of \(total)" : ""
    }

    private var chapterTitle: String { book.title }

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
                                Image(systemName: "checkmark").foregroundStyle(appTheme.accent)
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
