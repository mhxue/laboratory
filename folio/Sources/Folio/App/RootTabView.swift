import SwiftUI
import SwiftData
import EPUBKit

/// Root tab container — Library / Notes / Settings. Stats remains a
/// future-work tab; currently shows a placeholder to match the design.
struct RootTabView: View {
    let store: any BookStoring
    let container: ModelContainer

    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.colorScheme) private var colorScheme

    private var appTheme: AppTheme {
        AppTheme.from(settingsVM.stylesheet.theme, colorScheme)
    }

    var body: some View {
        TabView {
            LibraryView(
                viewModel: LibraryViewModel(store: store, context: container.mainContext),
                store: store
            )
            .tabItem { Label("Library", systemImage: "books.vertical") }

            NotesView(viewModel: NotesViewModel(context: container.mainContext))
                .tabItem { Label("Notes", systemImage: "highlighter") }

            StatsPlaceholderView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            SettingsView(viewModel: settingsVM)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(\.appTheme, appTheme)
        .tint(appTheme.accent)
        .preferredColorScheme(settingsVM.stylesheet.theme == .dark ? .dark : .light)
    }
}

/// Placeholder for the "Stats" tab — surfaced in the design but out of scope
/// for v1 functionality.
struct StatsPlaceholderView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(theme.tertiaryText)
                    Text("Reading stats coming soon")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.secondaryText)
                    Text("Streaks, time read, and per-book progress will live here.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("Stats")
        }
    }
}
