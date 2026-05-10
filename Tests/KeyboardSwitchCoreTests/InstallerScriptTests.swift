import Foundation
import XCTest
@testable import KeyboardSwitchCore

final class InstallerScriptTests: XCTestCase {
    func testPostinstallScriptBootstrapsSystemLaunchAgent() throws {
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "scripts/installer/postinstall")

        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains(DistributionLayout.systemLaunchAgentPath))
        XCTAssertTrue(script.contains("launchctl bootstrap"))
        XCTAssertTrue(script.contains("launchctl kickstart -k"))
        XCTAssertTrue(script.contains(LaunchAgentDefinition.keyboardMonitor.label))
    }
}
