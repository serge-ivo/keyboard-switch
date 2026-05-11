public enum DistributionLayout {
    public static let executableName = "KeyboardSwitch"
    public static let displayName = "Keyboard Switch"
    public static let bundleName = "\(displayName).app"
    public static let bundleIdentifier = "com.serge.keyboardswitch"
    public static let packageIdentifier = "com.serge.keyboardswitch.pkg"
    public static let appInstallDirectory = "/Applications"
    public static let appInstallPath = "\(appInstallDirectory)/\(bundleName)"
    public static let launchAgentPlistName = "com.serge.keyboardswitch.plist"
    public static let systemLaunchAgentsDirectory = "/Library/LaunchAgents"
    public static let systemLaunchAgentPath =
        "\(systemLaunchAgentsDirectory)/\(launchAgentPlistName)"
    public static let releaseAssetBaseName = executableName
    public static let diagnosticsLogFileName = "KeyboardSwitch.log"
}
