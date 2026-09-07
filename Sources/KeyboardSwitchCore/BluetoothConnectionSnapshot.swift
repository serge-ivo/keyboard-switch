import Foundation

public enum BluetoothConnectionSnapshot {
    public static func isDeviceConnected(named deviceName: String, in output: String) -> Bool {
        connectedDeviceNames(in: output).contains(deviceName)
    }

    public static func isDeviceConnected(
        configuredName: String,
        resolvedAddress: String?,
        in output: String
    ) -> Bool {
        let connectedNames = connectedDeviceNames(in: output)
        let devices = BluetoothDeviceCatalog.keyboardDevices(in: output)

        if let resolved = BluetoothTargetResolution.resolve(
            configuredName: configuredName,
            resolvedAddress: resolvedAddress,
            in: devices
        ), connectedNames.contains(resolved.name) {
            return true
        }

        return connectedNames.contains(configuredName)
    }

    public static func connectedDeviceNames(in output: String) -> Set<String> {
        let lines = output.components(separatedBy: .newlines)
        var inConnectedSection = false
        var connectedNames = Set<String>()

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed == "Connected:" {
                inConnectedSection = true
                continue
            }

            if trimmed == "Not Connected:" {
                inConnectedSection = false
                continue
            }

            guard inConnectedSection else { continue }

            // A device header is a bare `Name:` line. A field whose value is
            // empty (`Firmware Version:`) looks identical, so exclude the
            // known field names.
            if trimmed.hasSuffix(":"), !BluetoothDeviceCatalog.isFieldLine(trimmed) {
                let name = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    connectedNames.insert(name)
                }
            }
        }

        return connectedNames
    }
}
