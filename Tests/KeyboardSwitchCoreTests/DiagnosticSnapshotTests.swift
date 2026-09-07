import XCTest
@testable import KeyboardSwitchCore

final class DiagnosticSnapshotTests: XCTestCase {
    private func snapshot(
        connected: Bool = true,
        loadAverage: Double = 1.5,
        wifiBandGHz: Int? = 5,
        wifiChannel: Int? = 149,
        wifiRSSI: Int? = -46,
        wifiNoise: Int? = -85,
        wifiTxRateMbps: Double? = 866,
        secondsSinceLastKeystroke: Double? = 0.4,
        otherBluetoothDevices: [String] = []
    ) -> DiagnosticSnapshot {
        DiagnosticSnapshot(
            connected: connected,
            loadAverage: loadAverage,
            wifiBandGHz: wifiBandGHz,
            wifiChannel: wifiChannel,
            wifiRSSI: wifiRSSI,
            wifiNoise: wifiNoise,
            wifiTxRateMbps: wifiTxRateMbps,
            secondsSinceLastKeystroke: secondsSinceLastKeystroke,
            otherBluetoothDevices: otherBluetoothDevices
        )
    }

    func testSNRIsSignalMinusNoise() {
        XCTAssertEqual(snapshot(wifiRSSI: -46, wifiNoise: -85).wifiSNR, 39)
    }

    func testSNRIsUnavailableWhenEitherReadingIsMissing() {
        XCTAssertNil(snapshot(wifiRSSI: nil, wifiNoise: -85).wifiSNR)
        XCTAssertNil(snapshot(wifiRSSI: -46, wifiNoise: nil).wifiSNR)
    }

    func test24GHzSharesTheBluetoothBand() {
        XCTAssertTrue(snapshot(wifiBandGHz: 2).wifiSharesBluetoothBand)
    }

    func test5GHzDoesNotShareTheBluetoothBand() {
        XCTAssertFalse(snapshot(wifiBandGHz: 5).wifiSharesBluetoothBand)
    }

    func testUnknownBandIsNotReportedAsSharing() {
        XCTAssertFalse(snapshot(wifiBandGHz: nil).wifiSharesBluetoothBand)
    }

    /// The distinction the whole log exists to make: a drop that lands mid-typing
    /// is the one that corrupts input.
    func testRecentKeystrokeMarksTheDropAsWhileTyping() {
        XCTAssertTrue(snapshot(secondsSinceLastKeystroke: 0.4).logLine.contains("while_typing=true"))
    }

    func testIdleDropIsNotMarkedAsWhileTyping() {
        XCTAssertTrue(snapshot(secondsSinceLastKeystroke: 90).logLine.contains("while_typing=false"))
    }

    func testMissingKeystrokeTimingIsReportedAsUnknown() {
        let line = snapshot(secondsSinceLastKeystroke: nil).logLine
        XCTAssertTrue(line.contains("since_keystroke=unknown"))
        XCTAssertFalse(line.contains("while_typing="))
    }

    func testOtherBluetoothDevicesAreCountedAndNamedDeterministically() {
        let line = snapshot(otherBluetoothDevices: ["MK550MS", "Headset"]).logLine
        XCTAssertTrue(line.contains("bt_others=2"))
        XCTAssertTrue(line.contains("bt_other_names=Headset|MK550MS"))
    }

    func testNoOtherDevicesOmitsTheNameList() {
        let line = snapshot(otherBluetoothDevices: []).logLine
        XCTAssertTrue(line.contains("bt_others=0"))
        XCTAssertFalse(line.contains("bt_other_names="))
    }

    func testMissingWifiIsRecordedRatherThanOmitted() {
        let line = snapshot(wifiBandGHz: nil, wifiChannel: nil).logLine
        XCTAssertTrue(line.contains("wifi_band=none"))
        XCTAssertFalse(line.contains("wifi_ch="))
    }

    func testLogLineIsGreppableKeyValuePairs() {
        let line = snapshot(connected: false, loadAverage: 2.28).logLine
        XCTAssertTrue(line.contains("state=disconnected"))
        XCTAssertTrue(line.contains("load=2.28"))
        XCTAssertTrue(line.contains("wifi_ch=149"))
        XCTAssertTrue(line.contains("wifi_snr=39dB"))
        for pair in line.split(separator: " ") {
            XCTAssertTrue(pair.contains("="), "every field should be key=value, got \(pair)")
        }
    }
}
