import CoreGraphics
import CoreWLAN
import Foundation
import KeyboardSwitchCore

/// Gathers the system context around a connection change.
///
/// Everything here is an in-process call — no subprocess — so capturing a
/// snapshot costs microseconds and cannot itself disturb the thing being
/// measured. That matters: the previous design shelled out to `system_profiler`
/// on a timer, and we spent a long time unable to rule out the monitor as a
/// cause of what it was monitoring.
enum DiagnosticContext {
    static func snapshot(connected: Bool, otherBluetoothDevices: [String]) -> DiagnosticSnapshot {
        let wifi = CWWiFiClient.shared().interface()
        let channel = wifi?.wlanChannel()

        let band: Int?
        switch channel?.channelBand {
        case .band2GHz: band = 2
        case .band5GHz: band = 5
        default: band = nil
        }

        return DiagnosticSnapshot(
            connected: connected,
            loadAverage: currentLoadAverage(),
            wifiBandGHz: band,
            wifiChannel: channel?.channelNumber,
            // These read as 0 when Location Services has not been granted; a
            // real measurement is never 0 dBm, so treat it as unavailable.
            wifiRSSI: nonZero(wifi?.rssiValue()),
            wifiNoise: nonZero(wifi?.noiseMeasurement()),
            wifiTxRateMbps: wifi?.transmitRate(),
            secondsSinceLastKeystroke: secondsSinceLastKeystroke(),
            otherBluetoothDevices: otherBluetoothDevices
        )
    }

    private static func nonZero(_ value: Int?) -> Int? {
        guard let value, value != 0 else { return nil }
        return value
    }

    private static func currentLoadAverage() -> Double {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) > 0 else { return 0 }
        return loads[0]
    }

    /// Time since the last key press reached the window server. Needs no Input
    /// Monitoring permission and exposes no keystroke content — only timing.
    private static func secondsSinceLastKeystroke() -> Double? {
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        return seconds.isFinite ? seconds : nil
    }
}
