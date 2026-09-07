import Foundation

/// A point-in-time picture of everything that plausibly affects a Bluetooth
/// keyboard's link, captured whenever the connection state changes.
///
/// The connect/disconnect log alone cannot distinguish a radio problem from a
/// scheduling one, and says nothing at all about input arriving late on a link
/// that stays up. These fields are the discriminators: Wi-Fi band and signal
/// separate coexistence from interference, load separates CPU starvation from
/// both, and the count of other Bluetooth devices separates contention for the
/// controller from anything external.
public struct DiagnosticSnapshot: Equatable, Sendable {
    public let connected: Bool
    public let loadAverage: Double
    /// 2 for 2.4GHz, 5 for 5GHz — the band the Wi-Fi radio is using. On a combo
    /// chip, 2.4GHz means Wi-Fi and Bluetooth share spectrum.
    public let wifiBandGHz: Int?
    public let wifiChannel: Int?
    public let wifiRSSI: Int?
    public let wifiNoise: Int?
    public let wifiTxRateMbps: Double?
    /// Seconds since the last keystroke reached the window server. A long gap
    /// at a disconnect means the link died idle; a near-zero gap means it died
    /// mid-typing, which is the case that corrupts input.
    public let secondsSinceLastKeystroke: Double?
    /// Other Bluetooth devices sharing this controller's airtime.
    public let otherBluetoothDevices: [String]

    public init(
        connected: Bool,
        loadAverage: Double,
        wifiBandGHz: Int?,
        wifiChannel: Int?,
        wifiRSSI: Int?,
        wifiNoise: Int?,
        wifiTxRateMbps: Double?,
        secondsSinceLastKeystroke: Double?,
        otherBluetoothDevices: [String]
    ) {
        self.connected = connected
        self.loadAverage = loadAverage
        self.wifiBandGHz = wifiBandGHz
        self.wifiChannel = wifiChannel
        self.wifiRSSI = wifiRSSI
        self.wifiNoise = wifiNoise
        self.wifiTxRateMbps = wifiTxRateMbps
        self.secondsSinceLastKeystroke = secondsSinceLastKeystroke
        self.otherBluetoothDevices = otherBluetoothDevices
    }

    /// Signal-to-noise in dB, the number that actually predicts link quality.
    public var wifiSNR: Int? {
        guard let wifiRSSI, let wifiNoise else { return nil }
        return wifiRSSI - wifiNoise
    }

    /// True when Wi-Fi is in Bluetooth's band, so a combo chip must arbitrate
    /// between them.
    public var wifiSharesBluetoothBand: Bool {
        wifiBandGHz == 2
    }

    /// One grep-friendly line. Keys are fixed so a whole log can be parsed
    /// field-by-field later without re-reading the code that wrote it.
    public var logLine: String {
        var parts: [String] = []
        parts.append("state=\(connected ? "connected" : "disconnected")")
        parts.append(String(format: "load=%.2f", loadAverage))

        if let wifiBandGHz {
            parts.append("wifi_band=\(wifiBandGHz)GHz")
            parts.append("wifi_shares_bt_band=\(wifiSharesBluetoothBand)")
        } else {
            parts.append("wifi_band=none")
        }
        if let wifiChannel { parts.append("wifi_ch=\(wifiChannel)") }
        if let wifiRSSI { parts.append("wifi_rssi=\(wifiRSSI)dBm") }
        if let wifiNoise { parts.append("wifi_noise=\(wifiNoise)dBm") }
        if let wifiSNR { parts.append("wifi_snr=\(wifiSNR)dB") }
        if let wifiTxRateMbps {
            parts.append(String(format: "wifi_tx=%.0fMbps", wifiTxRateMbps))
        }
        if let secondsSinceLastKeystroke {
            parts.append(String(format: "since_keystroke=%.1fs", secondsSinceLastKeystroke))
            parts.append("while_typing=\(secondsSinceLastKeystroke < 5)")
        } else {
            parts.append("since_keystroke=unknown")
        }
        parts.append("bt_others=\(otherBluetoothDevices.count)")
        if !otherBluetoothDevices.isEmpty {
            parts.append("bt_other_names=\(otherBluetoothDevices.sorted().joined(separator: "|"))")
        }
        return parts.joined(separator: " ")
    }
}
