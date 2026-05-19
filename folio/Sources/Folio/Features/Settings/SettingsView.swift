import SwiftUI
import EPUBKit

struct SettingsView<VM: SettingsViewModeling>: View {
    @State var viewModel: VM
    @Environment(\.dismiss) private var dismiss

    init(viewModel: VM) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Font") {
                    Picker("Typeface", selection: $viewModel.stylesheet.font) {
                        ForEach(EPUBFont.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Size")
                            Spacer()
                            Text("\(Int(viewModel.stylesheet.fontSize))pt").foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.stylesheet.fontSize, in: 12...26, step: 1)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.stylesheet.theme) {
                        ForEach(EPUBTheme.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Spacing") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Line Height")
                            Spacer()
                            Text(String(format: "%.1f×", viewModel.stylesheet.lineSpacing))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.stylesheet.lineSpacing, in: 1.2...2.2, step: 0.1)
                    }
                }
            }
            .navigationTitle("Reading Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
