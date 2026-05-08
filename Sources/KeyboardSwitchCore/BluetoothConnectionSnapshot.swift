import Foundation

public enum BluetoothConnectionSnapshot {
    public static func isDeviceConnected(named deviceName: String, in output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        var inConnectedSection = false

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

            if trimmed == "\(deviceName):" {
                return true
            }
        }

        return false
    }
}
