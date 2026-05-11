import Foundation
import XCTest
@testable import KeyboardSwitchCore

final class KeyboardMonitorInfoPlistTests: XCTestCase {
    func testRepositoryInfoPlistDeclaresBluetoothUsageDescription() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Info.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(
            plist["CFBundleIdentifier"] as? String,
            DistributionLayout.bundleIdentifier
        )
        XCTAssertEqual(plist["CFBundleName"] as? String, DistributionLayout.displayName)
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, DistributionLayout.executableName)
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
        XCTAssertFalse((plist["CFBundleShortVersionString"] as? String ?? "").isEmpty)
        XCTAssertFalse((plist["CFBundleVersion"] as? String ?? "").isEmpty)
        XCTAssertEqual(
            plist["NSBluetoothAlwaysUsageDescription"] as? String,
            "Keyboard Switch checks your keyboard connection status so it can update the menu bar dot."
        )
    }
}
