import Foundation
import XCTest
@testable import KeyboardSwitchCore

final class LaunchAgentDefinitionTests: XCTestCase {
    func testDefaultLaunchAgentUsesOpenAppFlow() {
        XCTAssertEqual(LaunchAgentDefinition.keyboardMonitor.label, "com.serge.keyboardmonitor")
        XCTAssertEqual(
            LaunchAgentDefinition.keyboardMonitor.programArguments,
            ["/usr/bin/open", "-a", "/Applications/KeyboardMonitor.app"]
        )
    }

    func testRepositoryPlistMatchesExpectedProgramArguments() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "com.serge.keyboardmonitor.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, LaunchAgentDefinition.keyboardMonitor.label)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            LaunchAgentDefinition.keyboardMonitor.programArguments
        )
    }
}
