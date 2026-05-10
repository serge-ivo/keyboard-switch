import Foundation

public struct LaunchAgentDefinition: Equatable, Sendable {
    public let label: String
    public let appPath: String

    public init(label: String, appPath: String) {
        self.label = label
        self.appPath = appPath
    }

    public var programArguments: [String] {
        ["/usr/bin/open", "-a", appPath]
    }

    public static let keyboardMonitor = LaunchAgentDefinition(
        label: DistributionLayout.bundleIdentifier,
        appPath: DistributionLayout.appInstallPath
    )
}
