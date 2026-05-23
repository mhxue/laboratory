import SwiftUI

/// Small, all-caps, mono-spaced label — used for "CHAPTER 3", "12 / 47", section
/// headers in the design. Centralised so type sizing stays consistent.
struct MonoLabel: View {
    let text: String
    var color: Color = .secondary
    var size: CGFloat = 10
    var tracking: CGFloat = 1.4

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// Inter-Tight-style display headline — falls back to the system rounded
/// design on systems where the custom font isn't installed.
struct DisplayLabel: View {
    let text: String
    var size: CGFloat = 28
    var weight: Font.Weight = .bold
    var color: Color = .primary

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .kerning(-0.4)
            .foregroundStyle(color)
    }
}
