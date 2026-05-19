import Foundation
import SwiftData

private let seededKey = "folio.librarySeeded"

@MainActor
func seedLibraryIfNeeded(context: ModelContext) {
    guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
    guard let bundledEpub = Bundle.main.url(forResource: "pride_and_prejudice", withExtension: "epub") else { return }

    do {
        try BookStore().importBook(from: bundledEpub, context: context)
        UserDefaults.standard.set(true, forKey: seededKey)
    } catch {
        // Non-fatal: user can import manually
        print("[Folio] Seed failed: \(error)")
    }
}
