import SwiftUI

struct NotesView<VM: NotesViewModeling>: View {
    @State var viewModel: VM
    @Environment(\.appTheme) private var theme

    init(viewModel: VM) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DisplayLabel(text: "Notes", size: 28, weight: .heavy, color: theme.text)
                            .padding(.horizontal, 22)
                            .padding(.top, 8)

                        tabPicker
                            .padding(.horizontal, 22)

                        if viewModel.items.isEmpty {
                            emptyState
                                .padding(.top, 60)
                        } else {
                            highlightList
                                .padding(.horizontal, 22)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
            }
        }
    }

    // MARK: - Pieces

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(NotesTab.allCases, id: \.self) { tab in
                let isOn = viewModel.selectedTab == tab
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { viewModel.selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.displayName)
                            .font(.system(size: 12.5, weight: .medium))
                        let n = viewModel.count(for: tab)
                        if n > 0 {
                            Text("\(n)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .opacity(0.6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isOn ? theme.text : theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).stroke(isOn ? Color.clear : theme.border, lineWidth: 1)
                    )
                    .foregroundStyle(isOn ? theme.background : theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var highlightList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                highlightRow(item)
            }
        }
    }

    private func highlightRow(_ item: NoteItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: item.kind))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.bookTitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.tertiaryText)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(theme.text)
                } else {
                    Text("Bookmark at chapter \(item.chapterIndex + 1)")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(theme.text)
                }
                HStack {
                    Text("CH \(item.chapterIndex + 1)")
                        .foregroundStyle(color(for: item.kind))
                    Spacer()
                    Text(item.createdAt, format: .relative(presentation: .named))
                        .foregroundStyle(theme.tertiaryText)
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            }
            .padding(.leading, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func color(for kind: BookmarkKind) -> Color {
        switch kind {
        case .important:    return theme.accent
        case .connection:   return theme.success
        case .lookup:       return theme.warning
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "highlighter")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.tertiaryText)
            Text("No \(viewModel.selectedTab.displayName.lowercased()) yet")
                .font(.system(size: 14))
                .foregroundStyle(theme.secondaryText)
            Text("Highlights and bookmarks made in the reader will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}
