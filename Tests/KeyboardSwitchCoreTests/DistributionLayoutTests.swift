import XCTest
@testable import KeyboardSwitchCore

final class DistributionLayoutTests: XCTestCase {
    func testInstallerPathsMatchAppAndLaunchAgentContract() {
        XCTAssertEqual(DistributionLayout.appName, "KeyboardMonitor")
        XCTAssertEqual(DistributionLayout.bundleName, "KeyboardMonitor.app")
        XCTAssertEqual(DistributionLayout.bundleIdentifier, "com.serge.keyboardmonitor")
        XCTAssertEqual(DistributionLayout.packageIdentifier, "com.serge.keyboardmonitor.pkg")
        XCTAssertEqual(DistributionLayout.appInstallPath, "/Applications/KeyboardMonitor.app")
        XCTAssertEqual(
            DistributionLayout.systemLaunchAgentPath,
            "/Library/LaunchAgents/com.serge.keyboardmonitor.plist"
        )
    }
}
