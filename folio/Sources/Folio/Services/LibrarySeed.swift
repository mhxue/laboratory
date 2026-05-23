import Foundation
import SwiftData

private let seededKey = "folio.librarySeeded.v2"

private struct SeedEntry {
    let resource: String
    let expectedTitle: String
}

private let seedEntries: [SeedEntry] = [
    SeedEntry(resource: "pride_and_prejudice", expectedTitle: "Pride and Prejudice"),
    SeedEntry(resource: "sanguo_yanyi",        expectedTitle: "三国演义"),
    SeedEntry(resource: "shuihu_zhuan",        expectedTitle: "水浒传"),
    SeedEntry(resource: "xiyou_ji",            expectedTitle: "西游记"),
    SeedEntry(resource: "honglou_meng",        expectedTitle: "红楼梦"),
]

@MainActor
func seedLibraryIfNeeded(context: ModelContext) {
    guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

    let existingTitles = Set((try? context.fetch(FetchDescriptor<Book>()))?.map(\.title) ?? [])
    let store = BookStore()

    for entry in seedEntries {
        guard !existingTitles.contains(entry.expectedTitle) else { continue }
        guard let url = Bundle.main.url(forResource: entry.resource, withExtension: "epub") else {
            print("[Folio] Seed missing resource: \(entry.resource).epub")
            continue
        }
        do {
            _ = try store.importBook(from: url, context: context)
        } catch {
            print("[Folio] Seed failed for \(entry.resource): \(error)")
        }
    }

    UserDefaults.standard.set(true, forKey: seededKey)
}
