import AppKit
import XCTest
@testable import KeyboardSwitchCore

final class StatusDotAttributedTitleBuilderTests: XCTestCase {
    func testConnectedDotUsesGreenAttributedTitle() {
        let presentation = StatusDotPresenter.presentation(deviceName: "MK550KB", connected: true)
        let title = StatusDotAttributedTitleBuilder.build(presentation)

        XCTAssertEqual(title.string, "●")

        let color = title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor(srgbRed: 0.20, green: 0.82, blue: 0.33, alpha: 1.0))
    }

    func testDisconnectedDotUsesGrayAttributedTitle() {
        let presentation = StatusDotPresenter.presentation(deviceName: "MK550KB", connected: false)
        let title = StatusDotAttributedTitleBuilder.build(presentation)

        let color = title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor(srgbRed: 0.72, green: 0.72, blue: 0.75, alpha: 1.0))
    }
}
