import XCTest
@testable import KeyboardSwitchCore

final class BluetoothConnectionSnapshotTests: XCTestCase {
    func testRecognizesTargetInsideConnectedSection() {
        let output = """
        Bluetooth:

              Connected:
                  MK550KB:
                      Address: D6:3D:1F:F6:35:35
              Not Connected:
                  Keyboard K380:
                      Address: 34:88:5D:FB:51:57
        """

        XCTAssertTrue(BluetoothConnectionSnapshot.isDeviceConnected(named: "MK550KB", in: output))
    }

    func testDoesNotTreatNotConnectedSectionAsConnected() {
        let output = """
        Bluetooth:

              Connected:
                  MK550MS:
                      Address: D1:EC:DD:69:D4:DD
              Not Connected:
                  MK550KB:
                      Address: D6:3D:1F:F6:35:35
        """

        XCTAssertFalse(BluetoothConnectionSnapshot.isDeviceConnected(named: "MK550KB", in: output))
    }

    func testMatchesExactDeviceHeaderOnly() {
        let output = """
        Bluetooth:

              Connected:
                  MK550KB2:
                      Address: 00:00:00:00:00:00
        """

        XCTAssertFalse(BluetoothConnectionSnapshot.isDeviceConnected(named: "MK550KB", in: output))
    }

    func testEmptyValuedFieldIsNotTreatedAsADevice() {
        let output = """
        Bluetooth:

              Connected:
                  MK550KB:
                      Address: D6:3D:1F:F6:35:35
                      Firmware Version:
                      Battery Level:
        """

        let names = BluetoothConnectionSnapshot.connectedDeviceNames(in: output)

        XCTAssertEqual(names, ["MK550KB"])
    }
}
