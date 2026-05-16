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

    private var appTheme: AppTheme {
        AppTheme.from(settingsVM.stylesheet.theme, colorScheme)
    }

    var body: some View {
        ZStack {
            appTheme.background.ignoresSafeArea()

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
        ZStack(alignment: .top) {
            TabView(selection: $viewModel.currentChapterIndex) {
                ForEach(Array(viewModel.chapterURLs.enumerated()), id: \.offset) { index, url in
                    ChapterWebView(
                        chapterURL: url,
                        stylesheet: settingsVM.stylesheet
                    ) { fraction in
                        viewModel.scrollFraction = fraction
                    }
                    .tag(index)
                    .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.showChrome.toggle() }
            }

            if viewModel.showChrome {
                topChrome
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showChrome {
                bottomChrome
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            Text(book.title)
                .font(.caption.bold())
                .lineLimit(1)
            Spacer()
            Text("Ch \(viewModel.currentChapterIndex + 1) of \(viewModel.chapterURLs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            ProgressView(value: book.progressFraction)
                .tint(.accentColor)
                .padding(.horizontal)

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
        .background(.ultraThinMaterial)
    }

    // MARK: - TOC sheet

    private var tocSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapterURLs.enumerated()), id: \.offset) { index, _ in
                    Button {
                        viewModel.currentChapterIndex = index
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
