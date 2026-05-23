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
            RootTabView(store: store, container: container)
                .environment(settingsVM)
                .onAppear {
                    seedLibraryIfNeeded(context: container.mainContext)
                }
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1100, height: 760)
        #endif
        .modelContainer(container)
    }
}
