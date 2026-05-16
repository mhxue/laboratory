import SwiftUI
import WebKit
import EPUBKit

struct ChapterWebView: UIViewRepresentable {
    let url: URL
    let stylesheet: EPUBStylesheet
    let initialPage: Int
    var onReady: ((Int) -> Void)?
    var onPageChanged: ((Int) -> Void)?
    var onOverscrollForward: (() -> Void)?
    var onOverscrollBackward: (() -> Void)?
    /// zone: "left" | "center" | "right"  (left/right = 25%, center = 50%)
    var onTap: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            stylesheet: stylesheet,
            initialPage: initialPage,
            onReady: onReady,
            onPageChanged: onPageChanged,
            onOverscrollForward: onOverscrollForward,
            onOverscrollBackward: onOverscrollBackward,
            onTap: onTap
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "folio")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false

        context.coordinator.webView = webView

        webView.loadFileURL(
            url,
            allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent()
        )

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Re-inject CSS when stylesheet changes (after initial load)
        if context.coordinator.hasLoaded {
            context.coordinator.stylesheet = stylesheet
            context.coordinator.injectStyleAndPagination(in: webView)
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        var stylesheet: EPUBStylesheet
        var initialPage: Int
        var onReady: ((Int) -> Void)?
        var onPageChanged: ((Int) -> Void)?
        var onOverscrollForward: (() -> Void)?
        var onOverscrollBackward: (() -> Void)?
        var onTap: ((String) -> Void)?

        weak var webView: WKWebView?
        var totalPages: Int = 1
        var hasLoaded: Bool = false

        init(
            stylesheet: EPUBStylesheet,
            initialPage: Int,
            onReady: ((Int) -> Void)?,
            onPageChanged: ((Int) -> Void)?,
            onOverscrollForward: (() -> Void)?,
            onOverscrollBackward: (() -> Void)?,
            onTap: ((String) -> Void)?
        ) {
            self.stylesheet = stylesheet
            self.initialPage = initialPage
            self.onReady = onReady
            self.onPageChanged = onPageChanged
            self.onOverscrollForward = onOverscrollForward
            self.onOverscrollBackward = onOverscrollBackward
            self.onTap = onTap
        }

        func injectStyleAndPagination(in webView: WKWebView) {
            let pageWidth = webView.frame.width > 0 ? webView.frame.width : UIScreen.main.bounds.width

            let escapedCSS = stylesheet.css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")

            let js = """
            (function(css, pageWidth) {
                var s = document.getElementById('_folio') || document.createElement('style');
                s.id = '_folio'; s.textContent = css;
                document.head.appendChild(s);
                document.body.style.webkitColumnWidth = pageWidth + 'px';
                document.body.style.columnWidth       = pageWidth + 'px';
                document.body.style.columnGap         = '0px';
                setTimeout(function() {
                    var n = Math.max(1, Math.ceil(document.body.scrollWidth / pageWidth));
                    window.webkit.messageHandlers.folio.postMessage({type:'pageCount', count:n});
                }, 120);

                // Tap zone detection — runs once, won't block scroll gestures
                if (!window._folioTapBound) {
                    window._folioTapBound = true;
                    document.addEventListener('click', function(e) {
                        if (window.getSelection && window.getSelection().toString()) return;
                        var zone = e.clientX / window.innerWidth < 0.25 ? 'left'
                                 : e.clientX / window.innerWidth > 0.75 ? 'right'
                                 : 'center';
                        window.webkit.messageHandlers.folio.postMessage({type:'tap', zone:zone});
                    });
                }
            })(`\(escapedCSS)`, \(pageWidth));
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func scrollToPage(_ page: Int, animated: Bool) {
            guard let webView = webView else { return }
            let pageWidth = webView.frame.width
            let offset = CGPoint(x: CGFloat(page) * pageWidth, y: 0)
            webView.scrollView.setContentOffset(offset, animated: animated)
        }

        func handlePageCount(_ count: Int) {
            totalPages = count
            onReady?(count)
            if initialPage > 0 {
                scrollToPage(initialPage, animated: false)
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension ChapterWebView.Coordinator: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasLoaded = true
            self.injectStyleAndPagination(in: webView)
        }
    }
}

// MARK: - WKScriptMessageHandler

extension ChapterWebView.Coordinator: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Capture values we need from `message` on main actor before dispatching
        MainActor.assumeIsolated {
            guard message.name == "folio",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }
            switch type {
            case "pageCount":
                if let count = body["count"] as? Int { self.handlePageCount(count) }
            case "tap":
                if let zone = body["zone"] as? String { self.onTap?(zone) }
            default:
                break
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension ChapterWebView.Coordinator: UIScrollViewDelegate {
    nonisolated func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let pageWidth = scrollView.frame.width
            guard pageWidth > 0 else { return }
            let page = Int(round(scrollView.contentOffset.x / pageWidth))
            self.onPageChanged?(page)
        }
    }

    nonisolated func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // UIScrollViewDelegate is always called on the main thread.
        // We read totalPages from main-actor-isolated storage; since we're
        // guaranteed to be on the main thread here, we can safely assume isolation.
        // The pointer must be mutated synchronously (before this method returns),
        // so we cannot defer work to a DispatchQueue.
        let pageWidth = scrollView.frame.width
        guard pageWidth > 0 else { return }

        let targetX = targetContentOffset.pointee.x
        // Read totalPages safely — UIKit guarantees main thread delivery
        let pages = MainActor.assumeIsolated { self.totalPages }
        let maxX = CGFloat(pages - 1) * pageWidth

        if targetX < 0 {
            targetContentOffset.pointee.x = 0
            MainActor.assumeIsolated { self.onOverscrollBackward?() }
        } else if targetX > maxX {
            targetContentOffset.pointee.x = maxX
            MainActor.assumeIsolated { self.onOverscrollForward?() }
        }
    }
}
