import Cocoa
import KeyboardSwitchCore
import OSLog

@MainActor
final class KeyboardMonitor: NSObject, NSApplicationDelegate {
    private static let refreshInterval: TimeInterval = 0.5

    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var isConnected = false
    private let deviceName = "MK550KB"
    private let diagnostics = KeyboardMonitorDiagnostics()

    func applicationDidFinishLaunching(_ notification: Notification) {
        diagnostics.info("Application launching")
        let presentation = StatusDotPresenter.presentation(deviceName: deviceName, connected: false)
        statusItem = NSStatusBar.system.statusItem(withLength: presentation.width)
        diagnostics.info("Status item created with width \(presentation.width)")

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Open Log File",
                action: #selector(openLogFile),
                keyEquivalent: "l"
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu
        diagnostics.info("Status menu configured")

        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshConnectionState()
            }
        }
        refreshTimer?.tolerance = 0.05
        diagnostics.info("Refresh timer scheduled at \(Self.refreshInterval)s interval")
        refreshConnectionState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        diagnostics.info("Application terminating")
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func openLogFile() {
        diagnostics.revealLogFile()
    }

    private func updateStatus() {
        applyStatusDot(StatusDotPresenter.presentation(deviceName: deviceName, connected: isConnected))
    }

    private func applyStatusDot(_ presentation: StatusDotPresentation) {
        guard let button = statusItem.button else {
            diagnostics.error("Status item button was nil during applyStatusDot")
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = StatusDotAttributedTitleBuilder.build(presentation)
        button.toolTip = presentation.toolTip
    }

    private func refreshConnectionState() {
        guard !isRefreshing else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .utility).async { [weak self, deviceName, diagnostics] in
            let result = BluetoothStatusProbe.probe(deviceName: deviceName)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                if let error = result.errorDescription {
                    diagnostics.error("Bluetooth probe failed: \(error)")
                }
                if self.isConnected != result.connected {
                    diagnostics.info("Connection state changed to \(result.connected ? "connected" : "disconnected")")
                }
                self.isConnected = result.connected
                self.updateStatus()
            }
        }
    }
}

struct BluetoothProbeResult {
    let connected: Bool
    let errorDescription: String?
}

enum BluetoothStatusProbe {
    static func probe(deviceName: String) -> BluetoothProbeResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType"]

        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return BluetoothProbeResult(connected: false, errorDescription: "Unable to run system_profiler: \(error.localizedDescription)")
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard
            task.terminationStatus == 0,
            let output = String(data: data, encoding: .utf8)
        else {
            return BluetoothProbeResult(
                connected: false,
                errorDescription: "system_profiler exited with status \(task.terminationStatus)"
            )
        }

        return BluetoothProbeResult(
            connected: BluetoothConnectionSnapshot.isDeviceConnected(named: deviceName, in: output),
            errorDescription: nil
        )
    }
}

final class KeyboardMonitorDiagnostics: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.serge.keyboardmonitor", category: "menu-bar")
    private let queue = DispatchQueue(label: "com.serge.keyboardmonitor.diagnostics")
    private let fileURL: URL
    private let dateFormatter = ISO8601DateFormatter()

    init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/KeyboardSwitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        fileURL = logsDirectory.appendingPathComponent("KeyboardMonitor.log")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append(level: "INFO", message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append(level: "ERROR", message: message)
    }

    func revealLogFile() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            append(level: "INFO", message: "Log file created")
        }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func append(level: String, message: String) {
        let line = "\(dateFormatter.string(from: Date())) [\(level)] \(message)\n"
        queue.async { [fileURL] in
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if
                    let handle = try? FileHandle(forWritingTo: fileURL),
                    let _ = try? handle.seekToEnd()
                {
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = KeyboardMonitor()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
