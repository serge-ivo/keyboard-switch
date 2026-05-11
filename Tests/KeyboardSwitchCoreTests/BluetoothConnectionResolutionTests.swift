import XCTest
@testable import KeyboardSwitchCore

final class BluetoothConnectionResolutionTests: XCTestCase {
    func testResolvesRenamedKeyboardByAddress() {
        let output = """
        Bluetooth:

            Connected:
                Renamed Keyboard:

            Devices (Paired, Configured, etc.):
                Renamed Keyboard:
                    Address: D6-3D-1F-F6-35-35
                    Major Type: Peripheral
                    Minor Type: Keyboard
        """

        XCTAssertTrue(
            BluetoothConnectionSnapshot.isDeviceConnected(
                configuredName: "MK550KB",
                resolvedAddress: "d6:3d:1f:f6:35:35",
                in: output
            )
        )
    }
}
