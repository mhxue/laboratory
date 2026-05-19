import SwiftUI
import EPUBKit

/// Renders one ``PageLayout/Page``'s worth of ``EPUBBlock`` views inside a
/// full-screen `GeometryReader`, with tap-zone detection for page navigation.
struct EPUBPageView: View {
    let page: PageLayout.Page
    let blocks: [EPUBBlock]
    let stylesheet: EPUBStylesheet
    var deviceClass: DeviceClass = .compact
    /// Called with the tap zone: `"left"`, `"right"`, or `"center"`.
    var onTap: ((String) -> Void)?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(page.blockIndices, id: \.self) { i in
                        EPUBBlockView(block: blocks[i], stylesheet: stylesheet)
                    }
                    Spacer()
                }
                .padding(.horizontal, deviceClass.readerHorizontalPadding)
                .padding(.top, deviceClass.readerTopPadding)
                .padding(.bottom, deviceClass.readerBottomPadding)
                .frame(maxWidth: deviceClass.readerContentMaxWidth == .infinity
                       ? .infinity
                       : deviceClass.readerContentMaxWidth)
                .frame(maxWidth: .infinity)   // centre the content column
            }
            .scrollDisabled(true)             // paging handles navigation; disable scroll bounce
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let zone = location.x / geo.size.width < 0.25 ? "left"
                         : location.x / geo.size.width > 0.75 ? "right"
                         : "center"
                onTap?(zone)
            }
        }
    }
}
