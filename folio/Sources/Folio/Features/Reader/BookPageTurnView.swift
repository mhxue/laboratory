import SwiftUI
import UIKit
import EPUBKit

// MARK: - BookPageTurnView

/// Wraps `UIPageViewController` with `transitionStyle: .pageCurl` —
/// the same system-provided page-turn animation Apple Books uses.
/// All gesture handling, physics, and shadow rendering come for free.
struct BookPageTurnView: UIViewControllerRepresentable {

    let pages:       [PageLayout.Page]
    let blocks:      [EPUBBlock]
    let stylesheet:  EPUBStylesheet
    let deviceClass: DeviceClass

    @Binding var currentIndex: Int

    var canAdvanceChapter: Bool = false
    var canRetreatChapter: Bool = false

    var onAdvance:   (() -> Void)?
    var onRetreat:   (() -> Void)?
    var onTapCenter: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate   = context.coordinator
        pvc.view.backgroundColor = UIColor(Color(hex: stylesheet.theme.backgroundColor))

        context.coordinator.pvc = pvc
        context.coordinator.showPage(at: currentIndex, in: pvc, animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        pvc.view.addGestureRecognizer(tap)

        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        pvc.view.backgroundColor = UIColor(Color(hex: stylesheet.theme.backgroundColor))

        // Only push a programmatic page change if index drifted externally
        // (e.g. chapter navigation from chrome). Ignore while the user is mid-gesture.
        let coord = context.coordinator
        if currentIndex != coord.displayedIndex {
            coord.showPage(at: currentIndex, in: pvc, animated: false)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var parent: BookPageTurnView
        weak var pvc: UIPageViewController?
        var displayedIndex: Int = 0

        init(_ parent: BookPageTurnView) { self.parent = parent }

        func showPage(at index: Int, in pvc: UIPageViewController, animated: Bool) {
            guard !parent.pages.isEmpty,
                  let page = parent.pages[safe: index] else { return }
            let vc = makeVC(page: page, index: index)
            let dir: UIPageViewController.NavigationDirection = index >= displayedIndex ? .forward : .reverse
            displayedIndex = index
            pvc.setViewControllers([vc], direction: dir, animated: animated)
        }

        func makeVC(page: PageLayout.Page, index: Int) -> PageContentViewController {
            PageContentViewController(
                page: page,
                blocks: parent.blocks,
                stylesheet: parent.stylesheet,
                deviceClass: parent.deviceClass,
                index: index
            )
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let v = gr.view else { return }
            let x = gr.location(in: v).x / max(v.bounds.width, 1)
            if      x < 0.25 { parent.onRetreat?() }
            else if x > 0.75 { parent.onAdvance?() }
            else              { parent.onTapCenter?() }
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension BookPageTurnView.Coordinator: UIPageViewControllerDataSource {

    func pageViewController(_ pvc: UIPageViewController,
                            viewControllerBefore vc: UIViewController) -> UIViewController? {
        if let current = vc as? PageContentViewController {
            if current.index > 0 {
                let prev = current.index - 1
                guard let page = parent.pages[safe: prev] else { return nil }
                return makeVC(page: page, index: prev)
            } else if parent.canRetreatChapter {
                return ChapterBoundaryViewController(direction: .backward,
                                                    backgroundColor: parent.stylesheet.theme.backgroundColor)
            }
            return nil
        } else if let boundary = vc as? ChapterBoundaryViewController, boundary.direction == .forward {
            // User is reversing a forward-boundary swipe — give them the last page back.
            let lastIndex = parent.pages.count - 1
            guard let page = parent.pages[safe: lastIndex] else { return nil }
            return makeVC(page: page, index: lastIndex)
        }
        return nil
    }

    func pageViewController(_ pvc: UIPageViewController,
                            viewControllerAfter vc: UIViewController) -> UIViewController? {
        if let current = vc as? PageContentViewController {
            if current.index < parent.pages.count - 1 {
                let next = current.index + 1
                guard let page = parent.pages[safe: next] else { return nil }
                return makeVC(page: page, index: next)
            } else if parent.canAdvanceChapter {
                return ChapterBoundaryViewController(direction: .forward,
                                                    backgroundColor: parent.stylesheet.theme.backgroundColor)
            }
            return nil
        } else if let boundary = vc as? ChapterBoundaryViewController, boundary.direction == .backward {
            // User is reversing a backward-boundary swipe — give them the first page back.
            guard let page = parent.pages[safe: 0] else { return nil }
            return makeVC(page: page, index: 0)
        }
        return nil
    }
}

// MARK: - UIPageViewControllerDelegate

extension BookPageTurnView.Coordinator: UIPageViewControllerDelegate {

    func pageViewController(_ pvc: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let currentVC = pvc.viewControllers?.first
        else { return }

        let previousVC = previousViewControllers.first

        if let current = currentVC as? PageContentViewController {
            let newIndex = current.index
            displayedIndex = newIndex

            // User reversed a chapter-boundary swipe — landed back inside the chapter.
            if previousVC is ChapterBoundaryViewController { return }

            guard let prevIndex = (previousVC as? PageContentViewController)?.index else { return }
            if newIndex > prevIndex {
                parent.onAdvance?()
            } else if newIndex < prevIndex {
                parent.onRetreat?()
            }
        } else if let boundary = currentVC as? ChapterBoundaryViewController {
            // Chapter boundary crossed via swipe gesture.
            // Align displayedIndex with what the ViewModel will reset to (0) so that
            // updateUIViewController doesn't fire a stale showPage call before the old
            // BookPageTurnView is torn down.
            displayedIndex = 0
            if boundary.direction == .forward {
                parent.onAdvance?()
            } else {
                parent.onRetreat?()
            }
        }
    }
}

// MARK: - PageContentViewController

/// One page — hosts an `EPUBBlocksPageView` inside a `UIHostingController`.
final class PageContentViewController: UIViewController {

    let index: Int
    private let hosting: UIHostingController<EPUBBlocksPageView>

    init(page: PageLayout.Page, blocks: [EPUBBlock],
         stylesheet: EPUBStylesheet, deviceClass: DeviceClass, index: Int) {
        self.index = index
        self.hosting = UIHostingController(rootView: EPUBBlocksPageView(
            page: page, blocks: blocks,
            stylesheet: stylesheet, deviceClass: deviceClass
        ))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
    }
}

// MARK: - EPUBBlocksPageView

struct EPUBBlocksPageView: View {
    let page:        PageLayout.Page
    let blocks:      [EPUBBlock]
    let stylesheet:  EPUBStylesheet
    let deviceClass: DeviceClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(page.blockIndices, id: \.self) { i in
                if i < blocks.count {
                    EPUBBlockView(block: blocks[i], stylesheet: stylesheet)
                }
            }
            Spacer()
        }
        .padding(.horizontal, deviceClass.readerHorizontalPadding)
        .padding(.top,        deviceClass.readerTopPadding)
        .padding(.bottom,     deviceClass.readerBottomPadding)
        .frame(maxWidth: deviceClass.readerContentMaxWidth == .infinity
               ? .infinity : deviceClass.readerContentMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: stylesheet.theme.backgroundColor))
    }
}

// MARK: - ChapterBoundaryViewController

/// Shown as the placeholder page when the user swipes across a chapter boundary.
/// Displays the theme background so the curl looks natural; the real chapter
/// loads and replaces `BookPageTurnView` once `didFinishAnimating` fires.
final class ChapterBoundaryViewController: UIViewController {
    enum Direction { case forward, backward }
    let direction: Direction

    init(direction: Direction, backgroundColor: String) {
        self.direction = direction
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = UIColor(Color(hex: backgroundColor))
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Helpers

private extension Collection {
    subscript(safe i: Index) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
