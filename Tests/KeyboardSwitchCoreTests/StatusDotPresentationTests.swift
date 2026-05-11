import XCTest
@testable import KeyboardSwitchCore

final class StatusDotPresentationTests: XCTestCase {
    func testConnectedPresentationUsesAttributedGreenDot() {
        let presentation = StatusDotPresenter.presentation(deviceName: "MK550KB", connected: true)

        XCTAssertEqual(presentation.width, 26)
        XCTAssertEqual(presentation.renderer, .attributedTitle)
        XCTAssertEqual(presentation.symbol, "●")
        XCTAssertEqual(presentation.fontSize, 17)
        XCTAssertEqual(presentation.strokeWidth, -3)
        XCTAssertEqual(presentation.palette, .connectedGreen)
        XCTAssertEqual(presentation.toolTip, "MK550KB connected")
    }

    func testDisconnectedPresentationUsesGrayDotTooltip() {
        let presentation = StatusDotPresenter.presentation(deviceName: "MK550KB", connected: false)

        XCTAssertEqual(presentation.renderer, .attributedTitle)
        XCTAssertEqual(presentation.palette, .disconnectedGray)
        XCTAssertEqual(presentation.toolTip, "MK550KB not connected")
    }
}
