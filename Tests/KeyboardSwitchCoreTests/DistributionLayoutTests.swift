import XCTest
@testable import KeyboardSwitchCore

final class DistributionLayoutTests: XCTestCase {
    func testInstallerPathsMatchAppAndLaunchAgentContract() {
        XCTAssertEqual(DistributionLayout.executableName, "KeyboardSwitch")
        XCTAssertEqual(DistributionLayout.displayName, "Keyboard Switch")
        XCTAssertEqual(DistributionLayout.bundleName, "Keyboard Switch.app")
        XCTAssertEqual(DistributionLayout.bundleIdentifier, "com.serge.keyboardswitch")
        XCTAssertEqual(DistributionLayout.packageIdentifier, "com.serge.keyboardswitch.pkg")
        XCTAssertEqual(DistributionLayout.appInstallPath, "/Applications/Keyboard Switch.app")
        XCTAssertEqual(
            DistributionLayout.systemLaunchAgentPath,
            "/Library/LaunchAgents/com.serge.keyboardswitch.plist"
        )
    }
}
