import XCTest
@testable import KeyboardSwitchCore

final class BluetoothDeviceCatalogTests: XCTestCase {
    func testKeyboardDevicesExtractsKeyboardBlocks() {
        let output = """
        Bluetooth:

            Devices (Paired, Configured, etc.):
                Keyboard K380:
                    Address: 34-88-5D-FB-51-57
                    Major Type: Peripheral
                    Minor Type: Keyboard

                Magic Trackpad:
                    Address: 11-22-33-44-55-66
                    Major Type: Peripheral
                    Minor Type: Trackpad

                MK550KB:
                    Address: D6-3D-1F-F6-35-35
                    Major Type: Peripheral
                    Minor Type: Keyboard
        """

        let devices = BluetoothDeviceCatalog.keyboardDevices(in: output)

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].name, "Keyboard K380")
        XCTAssertEqual(devices[0].address, "34-88-5D-FB-51-57")
        XCTAssertEqual(devices[1].name, "MK550KB")
        XCTAssertEqual(devices[1].address, "D6-3D-1F-F6-35-35")
    }
}
