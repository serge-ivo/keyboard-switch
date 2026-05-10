import Foundation

public struct BluetoothDeviceIdentity: Equatable, Sendable {
    public let name: String?
    public let nameOrAddress: String?
    public let address: String?

    public init(name: String?, nameOrAddress: String?, address: String?) {
        self.name = name
        self.nameOrAddress = nameOrAddress
        self.address = address
    }
}

public enum BluetoothTargetResolution {
    public static func bestMatch(
        named configuredName: String,
        in devices: [BluetoothDeviceIdentity]
    ) -> BluetoothDeviceIdentity? {
        devices.first { matchesConfiguredName(configuredName, candidate: $0) }
    }

    public static func matchesTarget(
        configuredName: String,
        resolvedAddress: String?,
        candidate: BluetoothDeviceIdentity
    ) -> Bool {
        if
            let resolvedAddress = normalizedAddress(resolvedAddress),
            let candidateAddress = normalizedAddress(candidate.address),
            resolvedAddress == candidateAddress
        {
            return true
        }

        return matchesConfiguredName(configuredName, candidate: candidate)
    }

    public static func normalizedAddress(_ address: String?) -> String? {
        guard let address else { return nil }

        let hexScalars = address.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        let normalized = String(String.UnicodeScalarView(hexScalars)).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func matchesConfiguredName(
        _ configuredName: String,
        candidate: BluetoothDeviceIdentity
    ) -> Bool {
        candidate.name == configuredName || candidate.nameOrAddress == configuredName
    }
}
