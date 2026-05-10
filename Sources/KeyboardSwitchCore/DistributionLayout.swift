public enum DistributionLayout {
    public static let appName = "KeyboardMonitor"
    public static let bundleName = "\(appName).app"
    public static let bundleIdentifier = "com.serge.keyboardmonitor"
    public static let packageIdentifier = "com.serge.keyboardmonitor.pkg"
    public static let appInstallDirectory = "/Applications"
    public static let appInstallPath = "\(appInstallDirectory)/\(bundleName)"
    public static let launchAgentPlistName = "com.serge.keyboardmonitor.plist"
    public static let systemLaunchAgentsDirectory = "/Library/LaunchAgents"
    public static let systemLaunchAgentPath =
        "\(systemLaunchAgentsDirectory)/\(launchAgentPlistName)"
}
