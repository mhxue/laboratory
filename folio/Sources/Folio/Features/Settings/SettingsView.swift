import SwiftUI
import EPUBKit

/// Top-level "Settings" tab — wraps `TypographySheet` in a NavigationStack and
/// adds an "About / Ownership" footer for the main app screen. When presented
/// as a sheet from the reader, `presentedAsSheet` removes the navigation chrome.
struct SettingsView<VM: SettingsViewModeling>: View {
    @State var viewModel: VM
    var presentedAsSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    init(viewModel: VM, presentedAsSheet: Bool = false) {
        self._viewModel = State(initialValue: viewModel)
        self.presentedAsSheet = presentedAsSheet
    }

    var body: some View {
        if presentedAsSheet {
            TypographySheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        } else {
            NavigationStack {
                ScrollView {
                    TypographySheet(viewModel: viewModel)
                        .padding(.top, 12)

                    aboutCard
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                }
                .background(theme.background.ignoresSafeArea())
                .navigationTitle("Settings")
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(8)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.black.opacity(0.85))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yours forever")
                        .font(.system(size: 14, weight: .bold))
                        .kerning(-0.1)
                        .foregroundStyle(theme.text)
                    Text("Books stay on this device. No accounts, no cloud, no licence checks.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(14)
            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(theme.accent.opacity(0.4), lineWidth: 1)
            )
        }
    }
}
