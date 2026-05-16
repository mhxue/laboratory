import SwiftUI
import WebKit
import EPUBKit

struct ChapterWebView: UIViewRepresentable {
    let chapterURL: URL
    let stylesheet: EPUBStylesheet
    var onScrollFractionChange: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollFractionChange: onScrollFractionChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.scrollView.delegate = context.coordinator
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        context.coordinator.webView = webView
        loadContent(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        injectCSS(webView)
    }

    private func loadContent(_ webView: WKWebView) {
        webView.loadFileURL(
            chapterURL,
            allowingReadAccessTo: chapterURL.deletingLastPathComponent().deletingLastPathComponent()
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            injectCSS(webView)
        }
    }

    private func injectCSS(_ webView: WKWebView) {
        let escapedCSS = stylesheet.css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let js = """
        (function() {
            var existing = document.getElementById('folio-style');
            if (existing) existing.remove();
            var style = document.createElement('style');
            style.id = 'folio-style';
            style.textContent = `\(escapedCSS)`;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onScrollFractionChange: ((Double) -> Void)?
        weak var webView: WKWebView?

        init(onScrollFractionChange: ((Double) -> Void)?) {
            self.onScrollFractionChange = onScrollFractionChange
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maxOffset = scrollView.contentSize.height - scrollView.bounds.height
            guard maxOffset > 0 else { return }
            let fraction = Double(scrollView.contentOffset.y / maxOffset).clamped(to: 0...1)
            onScrollFractionChange?(fraction)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
