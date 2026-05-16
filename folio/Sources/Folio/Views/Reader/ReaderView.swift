import SwiftUI
import SwiftData

struct ReaderView: View {
    let book: Book
    let store: BookStore

    @Environment(ReaderSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var chapterURLs: [URL] = []
    @State private var currentChapter: Int = 0
    @State private var scrollFraction: Double = 0
    @State private var showChrome = true
    @State private var showTOC = false
    @State private var showSettingsSheet = false

    private let saveDebounce = DispatchWorkItem(flags: .barrier) {}

    var body: some View {
        ZStack {
            themeBackground.ignoresSafeArea()

            if chapterURLs.isEmpty {
                ProgressView("Opening book…")
            } else {
                readerContent
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showChrome)
        .onAppear(perform: loadBook)
        .onDisappear(perform: saveProgress)
        .sheet(isPresented: $showTOC) { tocSheet }
        .sheet(isPresented: $showSettingsSheet) { SettingsView() }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentChapter) {
                ForEach(Array(chapterURLs.enumerated()), id: \.offset) { index, url in
                    ChapterWebView(chapterURL: url, settings: settings) { fraction in
                        scrollFraction = fraction
                        debounceSave()
                    }
                    .tag(index)
                    .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showChrome.toggle() } }

            if showChrome {
                topChrome
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if showChrome {
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
            Text("Ch \(currentChapter + 1) of \(chapterURLs.count)")
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
                    let bm = Bookmark(chapterIndex: currentChapter, scrollFraction: scrollFraction)
                    book.bookmarks.append(bm)
                    try? context.save()
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
                ForEach(Array(chapterURLs.enumerated()), id: \.offset) { index, _ in
                    Button {
                        currentChapter = index
                        showTOC = false
                    } label: {
                        HStack {
                            Text("Chapter \(index + 1)")
                            Spacer()
                            if index == currentChapter {
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

    private var themeBackground: Color {
        switch settings.theme {
        case .light: return .white
        case .sepia: return Color(red: 0.96, green: 0.94, blue: 0.87)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        }
    }

    // MARK: - Helpers

    private func loadBook() {
        chapterURLs = (try? store.chapterURLs(for: book)) ?? []
        if let p = book.progress {
            currentChapter = p.chapterIndex
        }
    }

    private func saveProgress() {
        if book.progress == nil {
            let p = ReadingProgress(chapterIndex: currentChapter, scrollFraction: scrollFraction)
            book.progress = p
        } else {
            book.progress?.chapterIndex = currentChapter
            book.progress?.scrollFraction = scrollFraction
            book.progress?.lastRead = Date()
        }
        try? context.save()
    }

    private func debounceSave() {
        NSObject.cancelPreviousPerformRequests(withTarget: ProgressSaver.shared)
        ProgressSaver.shared.schedule(after: 5) { [self] in
            Task { @MainActor in saveProgress() }
        }
    }
}

// Simple debounce helper — avoids Timer retention in SwiftUI views
private final class ProgressSaver: @unchecked Sendable {
    static let shared = ProgressSaver()
    private var task: Task<Void, Never>?

    func schedule(after seconds: TimeInterval, action: @escaping @Sendable () -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run { action() }
            }
        }
    }
}
