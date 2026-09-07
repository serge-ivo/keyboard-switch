import XCTest
@testable import KeyboardSwitchCore

final class BluetoothTargetResolutionTests: XCTestCase {
    func testBestMatchFindsDeviceByExactName() {
        let devices = [
            BluetoothDeviceIdentity(name: "Keyboard K380", address: "34-88-5d-fb-51-57"),
            BluetoothDeviceIdentity(name: "MK550KB", address: "d6-3d-1f-f6-35-35")
        ]

        let match = BluetoothTargetResolution.bestMatch(named: "MK550KB", in: devices)

        XCTAssertEqual(match?.address, "d6-3d-1f-f6-35-35")
    }

    func testBestMatchDoesNotAcceptPrefixName() {
        let devices = [
            BluetoothDeviceIdentity(name: "MK550KB2", address: "00-00-00-00-00-00")
        ]

        let match = BluetoothTargetResolution.bestMatch(named: "MK550KB", in: devices)

        XCTAssertNil(match)
    }

    func testMatchesTargetByNormalizedAddress() {
        let candidate = BluetoothDeviceIdentity(
            name: "Renamed Keyboard",
            address: "D6-3D-1F-F6-35-35"
        )

        XCTAssertTrue(
            BluetoothTargetResolution.matchesTarget(
                configuredName: "MK550KB",
                resolvedAddress: "d6:3d:1f:f6:35:35",
                candidate: candidate
            )
        )
    }

    func testMatchesTargetFallsBackToConfiguredNameWhenAddressUnknown() {
        let candidate = BluetoothDeviceIdentity(
            name: "MK550KB",
            address: nil
        )

        XCTAssertTrue(
            BluetoothTargetResolution.matchesTarget(
                configuredName: "MK550KB",
                resolvedAddress: nil,
                candidate: candidate
            )
        )
    }

    func testResolvePrefersAddressMatch() {
        let devices = [
            BluetoothDeviceIdentity(name: "Renamed Keyboard", address: "D6-3D-1F-F6-35-35"),
            BluetoothDeviceIdentity(name: "MK550KB", address: "00-00-00-00-00-00")
        ]

        let match = BluetoothTargetResolution.resolve(
            configuredName: "MK550KB",
            resolvedAddress: "d6:3d:1f:f6:35:35",
            in: devices
        )

        XCTAssertEqual(match?.name, "Renamed Keyboard")
    }
}
