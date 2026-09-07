import Foundation

public enum BluetoothDeviceCatalog {
    public static func keyboardDevices(in output: String) -> [BluetoothDeviceIdentity] {
        let lines = output.components(separatedBy: .newlines)
        var devices: [BluetoothDeviceIdentity] = []
        var seenKeys = Set<String>()

        for index in lines.indices where lines[index].trimmingCharacters(in: .whitespaces) == "Minor Type: Keyboard" {
            guard let headerIndex = findDeviceHeader(before: index, in: lines) else { continue }

            let rawHeader = lines[headerIndex].trimmingCharacters(in: .whitespaces)
            guard rawHeader.hasSuffix(":") else { continue }

            let nameOrAddress = String(rawHeader.dropLast()).trimmingCharacters(in: .whitespaces)
            let address = findField(named: "Address", from: headerIndex + 1, through: index, in: lines)
            let key = BluetoothTargetResolution.normalizedAddress(address) ?? nameOrAddress

            guard !nameOrAddress.isEmpty, seenKeys.insert(key).inserted else { continue }

            devices.append(BluetoothDeviceIdentity(name: nameOrAddress, address: address))
        }

        return devices
    }

    private static func findDeviceHeader(before index: Int, in lines: [String]) -> Int? {
        var candidateIndex = index - 1
        while candidateIndex >= 0 {
            let rawLine = lines[candidateIndex]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                candidateIndex -= 1
                continue
            }

            if trimmed.hasSuffix(":") {
                let indent = rawLine.prefix { $0 == " " }.count
                if indent >= 8 && !isFieldLine(trimmed) {
                    return candidateIndex
                }
            }

            candidateIndex -= 1
        }

        return nil
    }

    private static func findField(
        named fieldName: String,
        from start: Int,
        through end: Int,
        in lines: [String]
    ) -> String? {
        guard start <= end else { return nil }

        for index in start...end {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            let prefix = "\(fieldName):"
            guard trimmed.hasPrefix(prefix) else { continue }

            let value = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        return nil
    }

    static func isFieldLine(_ trimmedLine: String) -> Bool {
        let fieldPrefixes = [
            "Address:",
            "Major Type:",
            "Minor Type:",
            "Services:",
            "Paired:",
            "Connected:",
            "Manufacturer:",
            "Battery Level:",
            "Firmware Version:",
            "Vendor ID:"
        ]

        return fieldPrefixes.contains { trimmedLine.hasPrefix($0) }
    }
}
