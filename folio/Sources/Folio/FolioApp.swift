import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var settings = ReaderSettings()
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
            LibraryView()
                .environment(settings)
                .onAppear {
                    seedLibraryIfNeeded(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
