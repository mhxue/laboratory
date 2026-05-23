import SwiftUI
import EPUBKit

/// Bottom-sheet reading-style picker — matches the design's "Typography" screen.
struct TypographySheet<VM: SettingsViewModeling>: View {
    @State var viewModel: VM
    @Environment(\.appTheme) private var theme

    init(viewModel: VM) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(theme.surface3)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            DisplayLabel(text: "Reading style", size: 22, weight: .heavy, color: theme.text)
                .padding(.bottom, 4)

            typefaceSegment

            sliderBlock(
                label: "Font size",
                value: $viewModel.stylesheet.fontSize,
                range: 12...26,
                step: 1,
                formatted: "\(Int(viewModel.stylesheet.fontSize)) pt"
            )

            sliderBlock(
                label: "Line height",
                value: $viewModel.stylesheet.lineSpacing,
                range: 1.2...2.2,
                step: 0.1,
                formatted: String(format: "%.1f×", viewModel.stylesheet.lineSpacing)
            )

            marginRow

            MonoLabel(text: "Theme", color: theme.tertiaryText)
            themeRow

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface1)
    }

    // MARK: - Pieces

    private var typefaceSegment: some View {
        HStack(spacing: 4) {
            ForEach(EPUBFont.allCases, id: \.self) { font in
                let isOn = viewModel.stylesheet.font == font
                Button {
                    viewModel.stylesheet.font = font
                } label: {
                    Text(font.displayName)
                        .font(.system(size: 14, weight: .semibold,
                                      design: font == .serif ? .serif : .default))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? theme.text : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isOn ? theme.background : theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(theme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1)
        )
    }

    private func sliderBlock(label: String,
                             value: Binding<Double>,
                             range: ClosedRange<Double>,
                             step: Double,
                             formatted: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonoLabel(text: label, color: theme.tertiaryText)
                Spacer()
                Text(formatted)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.text)
            }
            Slider(value: value, in: range, step: step)
                .tint(theme.accent)
        }
    }

    private var marginRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonoLabel(text: "Margin", color: theme.tertiaryText)
                Spacer()
                Text(viewModel.stylesheet.margin.displayName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.text)
            }
            HStack(spacing: 6) {
                ForEach(EPUBMargin.allCases, id: \.self) { margin in
                    let isOn = viewModel.stylesheet.margin == margin
                    Button {
                        viewModel.stylesheet.margin = margin
                    } label: {
                        Text(margin.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isOn ? theme.text : theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOn ? Color.clear : theme.border, lineWidth: 1)
                            )
                            .foregroundStyle(isOn ? theme.background : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var themeRow: some View {
        HStack(spacing: 10) {
            ForEach(EPUBTheme.allCases, id: \.self) { epubTheme in
                let isOn = viewModel.stylesheet.theme == epubTheme
                Button {
                    viewModel.stylesheet.theme = epubTheme
                } label: {
                    themeSwatch(epubTheme)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isOn ? theme.accent : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func themeSwatch(_ epubTheme: EPUBTheme) -> some View {
        let palette = AppTheme.from(epubTheme, .dark)
        return VStack {
            Spacer()
            Text(epubTheme.rawValue.capitalized.uppercased())
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(palette.text)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // mock paragraph lines
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(palette.text.opacity(0.6)).frame(height: 2)
                RoundedRectangle(cornerRadius: 1).fill(palette.text.opacity(0.45)).frame(height: 2)
                RoundedRectangle(cornerRadius: 1).fill(palette.text.opacity(0.45)).frame(height: 2)
                Spacer()
            }
            .padding(10)
        )
    }
}
