import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var settingsVM = SettingsViewModel()
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Book.self, ReadingProgress.self, Bookmark.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            let store = BookStore()
            let libraryVM = LibraryViewModel(store: store, context: container.mainContext)
            LibraryView(viewModel: libraryVM, store: store)
                .environment(settingsVM)
                .onAppear {
                    seedLibraryIfNeeded(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
