import XCTest
@testable import EPUBKit

final class EPUBStylesheetTests: XCTestCase {

    // MARK: Default values

    func test_default_fontSize_is18() {
        XCTAssertEqual(EPUBStylesheet.default.fontSize, 18)
    }

    func test_default_lineSpacing_is1_6() {
        XCTAssertEqual(EPUBStylesheet.default.lineSpacing, 1.6, accuracy: 0.001)
    }

    func test_default_theme_isLight() {
        XCTAssertEqual(EPUBStylesheet.default.theme, .light)
    }

    func test_default_font_isSerif() {
        XCTAssertEqual(EPUBStylesheet.default.font, .serif)
    }

    // MARK: CSS font-size

    func test_css_containsFontSize() {
        var sheet = EPUBStylesheet.default
        sheet.fontSize = 20
        XCTAssertTrue(sheet.css.contains("font-size: 20.0px"), "CSS should contain font-size: 20.0px")
    }

    func test_css_containsLineSpacing() {
        var sheet = EPUBStylesheet.default
        sheet.lineSpacing = 2.0
        XCTAssertTrue(sheet.css.contains("line-height: 2.0"), "CSS should contain line-height: 2.0")
    }

    // MARK: Theme background colours

    func test_css_light_backgroundIsWhite() {
        var sheet = EPUBStylesheet.default
        sheet.theme = .light
        XCTAssertTrue(sheet.css.contains("#FFFFFF"), "Light theme should use #FFFFFF background")
    }

    func test_css_sepia_backgroundIsCream() {
        var sheet = EPUBStylesheet.default
        sheet.theme = .sepia
        XCTAssertTrue(sheet.css.contains("#F5EDD6"), "Sepia theme should use #F5EDD6 background")
    }

    func test_css_dark_backgroundIsDark() {
        var sheet = EPUBStylesheet.default
        sheet.theme = .dark
        XCTAssertTrue(sheet.css.contains("#161618"), "Dark theme should use #161618 background")
    }

    // MARK: Theme text colours

    func test_css_light_textColorIsDark() {
        var sheet = EPUBStylesheet.default
        sheet.theme = .light
        XCTAssertTrue(sheet.css.contains("color: #1A1A1A"), "Light theme text should be #1A1A1A")
    }

    func test_css_dark_textColorIsLight() {
        var sheet = EPUBStylesheet.default
        sheet.theme = .dark
        XCTAssertTrue(sheet.css.contains("color: #E8E8ED"), "Dark theme text should be #E8E8ED")
    }

    // MARK: Font families

    func test_css_serif_fontFamily() {
        var sheet = EPUBStylesheet.default
        sheet.font = .serif
        XCTAssertTrue(sheet.css.contains("Georgia"), "Serif should use Georgia")
    }

    func test_css_sansSerif_fontFamily() {
        var sheet = EPUBStylesheet.default
        sheet.font = .sansSerif
        XCTAssertTrue(sheet.css.contains("-apple-system"), "Sans-serif should use -apple-system")
    }

    // MARK: Equatable

    func test_equatable_sameValues_areEqual() {
        let a = EPUBStylesheet(fontSize: 18, lineSpacing: 1.6, theme: .light, font: .serif)
        let b = EPUBStylesheet(fontSize: 18, lineSpacing: 1.6, theme: .light, font: .serif)
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentTheme_notEqual() {
        let a = EPUBStylesheet(fontSize: 18, lineSpacing: 1.6, theme: .light, font: .serif)
        let b = EPUBStylesheet(fontSize: 18, lineSpacing: 1.6, theme: .dark,  font: .serif)
        XCTAssertNotEqual(a, b)
    }
}
