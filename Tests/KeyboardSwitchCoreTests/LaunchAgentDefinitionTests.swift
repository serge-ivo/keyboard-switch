import Foundation
import XCTest
@testable import KeyboardSwitchCore

final class LaunchAgentDefinitionTests: XCTestCase {
    func testDefaultLaunchAgentUsesOpenAppFlow() {
        XCTAssertEqual(LaunchAgentDefinition.keyboardSwitch.label, "com.serge.keyboardswitch")
        XCTAssertEqual(
            LaunchAgentDefinition.keyboardSwitch.programArguments,
            ["/usr/bin/open", "-a", "/Applications/Keyboard Switch.app"]
        )
    }

    func testRepositoryPlistMatchesExpectedProgramArguments() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "com.serge.keyboardswitch.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, LaunchAgentDefinition.keyboardSwitch.label)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            LaunchAgentDefinition.keyboardSwitch.programArguments
        )
    }
}
