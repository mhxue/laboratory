# Folio — Architecture Conventions

## Overview

Folio is an iOS 17+ EPUB reader built with SwiftUI, SwiftData, and a local Swift Package (`EPUBKit`). It targets Swift 6 with strict concurrency.

## Project Structure

```
folio/
├── Packages/EPUBKit/          ← Pure-Swift local package (no UIKit)
│   ├── Sources/EPUBKit/
│   └── Tests/EPUBKitTests/
├── Sources/Folio/
│   ├── App/                   ← @main entry point only
│   ├── Features/
│   │   ├── Library/           ← LibraryViewModeling (protocol) + LibraryViewModel + LibraryView
│   │   ├── Reader/            ← ReaderViewModeling  (protocol) + ReaderViewModel  + ReaderView
│   │   └── Settings/          ← SettingsViewModeling (protocol) + SettingsViewModel + SettingsView
│   ├── Services/
│   │   ├── BookStoring.swift  ← protocol
│   │   ├── BookStore.swift    ← @MainActor impl (uses EPUBKit)
│   │   └── LibrarySeed.swift
│   ├── Models/
│   │   └── Book.swift         ← SwiftData models (Book, ReadingProgress, Bookmark)
│   └── Theme/
│       └── AppTheme.swift     ← Colour tokens + EnvironmentKey
└── Tests/FolioTests/          ← Unit tests for ViewModels
```

## Packages

### EPUBKit (`Packages/EPUBKit/`)

A pure-Swift package with **no UIKit/AppKit dependency**. The app target must not import `ZIPFoundation` directly — only `EPUBKit` does.

Key public types:
| Type | Kind | Purpose |
|------|------|---------|
| `EPUBParsing` | protocol | Parses a `.epub` URL into an `EPUBDocument` |
| `EPUBParser` | class | Concrete implementation using ZIPFoundation |
| `EPUBDocument` | struct | Parsed result: metadata + chapters + TOC |
| `EPUBMetadata` | struct | title, author, coverImageData, language |
| `EPUBChapter` | struct | Identifiable; `url` points to extracted HTML |
| `EPUBTOCItem` | struct | Identifiable; label + chapterIndex |
| `EPUBStylesheet` | struct | Typography + theme value type; generates CSS |
| `EPUBTheme` | enum | `.light` / `.sepia` / `.dark` |
| `EPUBFont` | enum | `.serif` / `.sansSerif` |

All public types are `Sendable`.

## Architecture Pattern — MVVM + POP

### Protocol-Oriented ViewModels

Each feature has:
1. `*ViewModeling.swift` — `@MainActor` protocol (written first per TDD order)
2. `*ViewModel.swift` — `@Observable` concrete implementation
3. `*View.swift` — SwiftUI view **generic over the protocol**

```swift
struct LibraryView<VM: LibraryViewModeling>: View {
    @State var viewModel: VM
    ...
}
```

This lets tests and Previews inject mock ViewModels without touching production code.

### TDD Order (always follow this)

For every new component:
1. Write the **protocol** file
2. Write the **test** file (referencing the protocol; use a mock conformance)
3. Write the **implementation**

### BookStoring Protocol

`BookStoring` is the seam between the UI layer and the file system / EPUBKit:

```swift
@MainActor
protocol BookStoring {
    func importBook(from url: URL, context: ModelContext) throws -> Book
    func deleteBook(_ book: Book, context: ModelContext) throws
    func chapterURLs(for book: Book) throws -> [URL]
    func coverImage(for book: Book) -> UIImage?
}
```

`BookStore` (the concrete implementation) uses `EPUBParser` via the `EPUBParsing` protocol, so parsers can also be mocked in unit tests.

## Theme System

`EPUBStylesheet` (value type in EPUBKit) drives both the WebView CSS and the SwiftUI chrome:

- `SettingsViewModel` owns the stylesheet and persists it via `UserDefaults`
- `SettingsViewModel` is passed through the SwiftUI environment (`.environment(settingsVM)`)
- `ReaderView` reads the stylesheet from the environment via `@Environment(SettingsViewModel.self)`
- `AppTheme` (in `Theme/`) maps `EPUBTheme` + `ColorScheme` to named `Color` tokens; it is available via `\.appTheme` environment key

## SwiftData Models

Defined in `Models/Book.swift`. **Do not change the schema** without also writing a migration — other features depend on it.

Models: `Book`, `ReadingProgress` (1-to-1 cascade), `Bookmark` (1-to-many cascade).

## Build Commands

```bash
# Regenerate Xcode project from project.yml
xcodegen generate

# Build for simulator
xcodebuild -project Folio.xcodeproj -scheme Folio \
  -destination 'generic/platform=iOS Simulator' build

# Run app tests (includes FolioTests target)
xcodebuild -project Folio.xcodeproj -scheme Folio \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run EPUBKit package tests (fast, no simulator needed)
swift test --package-path Packages/EPUBKit
```

## Constraints

- iOS 17+ deployment target, Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`
- Only `EPUBKit` imports `ZIPFoundation`; the app target must not add it directly
- All public EPUBKit types must be `Sendable` (or explicitly annotated)
- No breaking changes to `Book.swift` SwiftData models
