import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var settings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(settings)
        }
        .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self])
    }
}
