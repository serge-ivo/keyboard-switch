import Foundation
import KeyboardSwitchCore

@MainActor
final class KeyboardSwitchConfiguration {
    private enum Keys {
        static let monitoredKeyboardName = "monitoredKeyboardName"
        static let monitoredKeyboardAddress = "monitoredKeyboardAddress"
    }

    private let userDefaults: UserDefaults
    private let defaultKeyboardName = "MK550KB"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var monitoredKeyboardName: String {
        let value = userDefaults.string(forKey: Keys.monitoredKeyboardName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? defaultKeyboardName
    }

    var monitoredKeyboardAddress: String? {
        userDefaults.string(forKey: Keys.monitoredKeyboardAddress)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveSelection(name: String, address: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userDefaults.set(trimmedName.isEmpty ? defaultKeyboardName : trimmedName, forKey: Keys.monitoredKeyboardName)

        let trimmedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedAddress, !trimmedAddress.isEmpty {
            userDefaults.set(trimmedAddress, forKey: Keys.monitoredKeyboardAddress)
        } else {
            userDefaults.removeObject(forKey: Keys.monitoredKeyboardAddress)
        }
    }

    func updateResolvedAddressIfNeeded(from device: BluetoothDeviceIdentity?) {
        guard let address = device?.address, !address.isEmpty else { return }
        if BluetoothTargetResolution.normalizedAddress(address) != BluetoothTargetResolution.normalizedAddress(monitoredKeyboardAddress) {
            userDefaults.set(address, forKey: Keys.monitoredKeyboardAddress)
        }
    }
}
