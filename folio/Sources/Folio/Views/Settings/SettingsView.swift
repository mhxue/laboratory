import SwiftUI

struct SettingsView: View {
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section("Font") {
                    Picker("Typeface", selection: $s.font) {
                        ForEach(ReaderFont.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Size")
                            Spacer()
                            Text("\(Int(settings.fontSize))pt").foregroundStyle(.secondary)
                        }
                        Slider(value: $s.fontSize, in: 12...26, step: 1)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $s.theme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { t in
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
                            Text(String(format: "%.1f×", settings.lineSpacing)).foregroundStyle(.secondary)
                        }
                        Slider(value: $s.lineSpacing, in: 1.2...2.2, step: 0.1)
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
