import XCTest
import SwiftUI
import EPUBKit
@testable import Folio

final class AppThemeTests: XCTestCase {

    // MARK: - Distinct palettes per EPUBTheme

    func test_themes_haveDistinctBackgrounds() {
        let light = AppTheme.from(.light, .light).background.description
        let sepia = AppTheme.from(.sepia, .light).background.description
        let dark  = AppTheme.from(.dark,  .dark).background.description
        XCTAssertNotEqual(light, sepia)
        XCTAssertNotEqual(sepia, dark)
        XCTAssertNotEqual(light, dark)
    }

    func test_dark_background_isPureBlackish() {
        // Sanity: dark surface should match the design token #0A0A0B.
        let dark = AppTheme.from(.dark, .dark)
        XCTAssertEqual(dark.background.description, Color(hex: "#0A0A0B").description)
    }

    func test_accent_matchesEPUBLinkColor_inDark() {
        // The amber accent should mirror EPUBTheme.dark's link colour so the
        // reader chrome and the body link styling feel of a piece.
        let dark = AppTheme.from(.dark, .dark)
        XCTAssertEqual(dark.accent.description, Color(hex: EPUBTheme.dark.linkColor).description)
    }

    func test_themesAreEquatable_sameInputProducesEqualTheme() {
        let a = AppTheme.from(.dark, .dark)
        let b = AppTheme.from(.dark, .dark)
        XCTAssertEqual(a, b)
    }

    func test_themesAreNotEqual_acrossEPUBThemes() {
        XCTAssertNotEqual(AppTheme.from(.light, .light), AppTheme.from(.dark, .dark))
    }

    // MARK: - hex initialiser

    func test_color_hex_distinctInputsProduceDistinctColors() {
        XCTAssertNotEqual(Color(hex: "#FF9F5B").description, Color(hex: "#0A0A0B").description)
    }

    func test_color_hex_6digit_includesRedComponent() {
        // The Color description embeds the components — use it as a smoke test.
        let desc = Color(hex: "#FF0000").description
        XCTAssertFalse(desc.isEmpty)
        // Two reds parsed via different paths should match.
        XCTAssertEqual(Color(hex: "#FF0000").description, Color(hex: "#ff0000").description)
    }

    func test_color_hex_8digit_alphaAffectsOutput() {
        let solid = Color(hex: "#FF9F5BFF").description
        let half  = Color(hex: "#FF9F5B80").description
        XCTAssertNotEqual(solid, half)
    }

    func test_color_hex_malformed_doesNotCrash() {
        // Just exercising the path — we don't care about the exact value, only
        // that the initialiser is defensive.
        _ = Color(hex: "#XYZ")
        _ = Color(hex: "")
        _ = Color(hex: "#1")
    }

    // MARK: - Token coverage

    func test_everyEpubTheme_resolves_allTokenChannels() {
        // Smoke: just iterate all combinations and ensure the factory doesn't
        // trap (defensive against future palette additions).
        for theme in EPUBTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let t = AppTheme.from(theme, scheme)
                XCTAssertFalse(t.background.description.isEmpty)
                XCTAssertFalse(t.accent.description.isEmpty)
                XCTAssertFalse(t.text.description.isEmpty)
            }
        }
    }
}
