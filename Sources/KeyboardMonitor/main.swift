import Cocoa
import KeyboardSwitchCore
import OSLog

@MainActor
final class KeyboardSwitchApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindowController: KeyboardSettingsWindowController?
    private var presenceWatcher: HIDPresenceWatcher?
    private var isRefreshing = false
    private var isConnected = false
    private var latestKnownDevices: [BluetoothDeviceIdentity] = []
    private var lastResolvedDevice: BluetoothDeviceIdentity?
    private let configuration = KeyboardSwitchConfiguration(userDefaults: .standard)
    private let diagnostics = KeyboardSwitchDiagnostics()

    func applicationDidFinishLaunching(_ notification: Notification) {
        diagnostics.info("Application launching")
        let presentation = StatusDotPresenter.presentation(deviceName: monitoredDeviceDisplayName, connected: false)
        statusItem = NSStatusBar.system.statusItem(withLength: presentation.width)
        diagnostics.info("Status item created with width \(presentation.width)")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openSettingsWindow)
        statusItem.button?.sendAction(on: [.leftMouseUp])
        diagnostics.info("Status item click handler configured")

        presenceWatcher = HIDPresenceWatcher { [weak self] in
            Task { @MainActor in
                self?.refreshConnectionState()
            }
        }
        diagnostics.info("HID presence watcher registered")
        refreshConnectionState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        diagnostics.info("Application terminating")
        presenceWatcher = nil
    }

    @objc private func openLogFile() {
        diagnostics.revealLogFile()
    }

    @objc private func openSettingsWindow() {
        refreshConnectionState()

        if settingsWindowController == nil {
            settingsWindowController = KeyboardSettingsWindowController(
                configuration: configuration,
                diagnostics: diagnostics,
                onSave: { [weak self] in
                    self?.refreshConnectionState()
                    self?.updateStatus()
                },
                onOpenLog: { [weak self] in
                    self?.openLogFile()
                },
                snapshotProvider: { [weak self] in
                    self?.settingsSnapshot ?? KeyboardSettingsSnapshot(
                        devices: [],
                        monitoredName: "MK550KB",
                        monitoredAddress: nil,
                        statusText: "No keyboard selected"
                    )
                }
            )
        }

        let snapshot = settingsSnapshot
        settingsWindowController?.present(
            devices: snapshot.devices,
            monitoredName: snapshot.monitoredName,
            monitoredAddress: snapshot.monitoredAddress,
            statusText: snapshot.statusText
        )
    }

    private func updateStatus() {
        applyStatusDot(StatusDotPresenter.presentation(deviceName: monitoredDeviceDisplayName, connected: isConnected))
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

        let configuredName = configuration.monitoredKeyboardName
        let configuredAddress = configuration.monitoredKeyboardAddress

        DispatchQueue.global(qos: .utility).async { [weak self, configuredName, configuredAddress, diagnostics] in
            let result = BluetoothStatusProbe.probe(
                configuredName: configuredName,
                configuredAddress: configuredAddress
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                if let error = result.errorDescription {
                    diagnostics.error("Bluetooth probe failed: \(error)")
                }
                if self.isConnected != result.connected {
                    diagnostics.info("Connection state changed to \(result.connected ? "connected" : "disconnected")")
                }
                self.latestKnownDevices = result.devices
                self.lastResolvedDevice = result.resolvedDevice
                self.configuration.updateResolvedAddressIfNeeded(from: result.resolvedDevice)
                self.isConnected = result.connected
                self.updateStatus()
            }
        }
    }

    private var monitoredDeviceDisplayName: String {
        lastResolvedDevice?.name ?? configuration.monitoredKeyboardName
    }

    private var settingsSnapshot: KeyboardSettingsSnapshot {
        let statusText = isConnected
            ? "\(monitoredDeviceDisplayName) is connected"
            : "\(monitoredDeviceDisplayName) is not connected"

        return KeyboardSettingsSnapshot(
            devices: latestKnownDevices,
            monitoredName: configuration.monitoredKeyboardName,
            monitoredAddress: configuration.monitoredKeyboardAddress,
            statusText: statusText
        )
    }
}

struct BluetoothProbeResult {
    let connected: Bool
    let errorDescription: String?
    let devices: [BluetoothDeviceIdentity]
    let resolvedDevice: BluetoothDeviceIdentity?
}

enum BluetoothStatusProbe {
    /// system_profiler occasionally wedges. Without a bound, `waitUntilExit()`
    /// would block forever and the caller's in-flight guard would never clear,
    /// freezing the status dot for the rest of the session.
    private static let timeout: TimeInterval = 10.0

    static func probe(configuredName: String, configuredAddress: String?) -> BluetoothProbeResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType"]

        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return BluetoothProbeResult(
                connected: false,
                errorDescription: "Unable to run system_profiler: \(error.localizedDescription)",
                devices: [],
                resolvedDevice: nil
            )
        }

        // Terminating the process closes its stdout, which releases the read
        // below and lets waitUntilExit() return.
        let watchdog = DispatchWorkItem {
            if task.isRunning {
                task.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        watchdog.cancel()

        guard
            task.terminationStatus == 0,
            let output = String(data: data, encoding: .utf8)
        else {
            return BluetoothProbeResult(
                connected: false,
                errorDescription: "system_profiler exited with status \(task.terminationStatus)",
                devices: [],
                resolvedDevice: nil
            )
        }

        let devices = BluetoothDeviceCatalog.keyboardDevices(in: output)
        let resolvedDevice = BluetoothTargetResolution.resolve(
            configuredName: configuredName,
            resolvedAddress: configuredAddress,
            in: devices
        )

        return BluetoothProbeResult(
            connected: BluetoothConnectionSnapshot.isDeviceConnected(
                configuredName: configuredName,
                resolvedAddress: configuredAddress,
                in: output
            ),
            errorDescription: nil,
            devices: devices,
            resolvedDevice: resolvedDevice
        )
    }
}

final class KeyboardSwitchDiagnostics: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.serge.keyboardswitch", category: "menu-bar")
    private let queue = DispatchQueue(label: "com.serge.keyboardswitch.diagnostics")
    private let fileURL: URL
    private let dateFormatter = ISO8601DateFormatter()

    init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/KeyboardSwitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        fileURL = logsDirectory.appendingPathComponent(DistributionLayout.diagnosticsLogFileName)
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

    /// At the cap the current log becomes `.1`, replacing any previous one, and
    /// logging restarts in a fresh file — so at most two of these are ever on
    /// disk. Connect/disconnect history is worth keeping, but not unboundedly.
    private static let maxLogBytes = 1_000_000

    private static func rotateIfNeeded(at fileURL: URL) {
        let manager = FileManager.default
        guard
            let attributes = try? manager.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? Int,
            size > maxLogBytes
        else { return }

        let rotated = fileURL.appendingPathExtension("1")
        try? manager.removeItem(at: rotated)
        try? manager.moveItem(at: fileURL, to: rotated)
    }

    private func append(level: String, message: String) {
        let line = "\(dateFormatter.string(from: Date())) [\(level)] \(message)\n"
        queue.async { [fileURL] in
            let data = Data(line.utf8)
            KeyboardSwitchDiagnostics.rotateIfNeeded(at: fileURL)
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
let delegate = KeyboardSwitchApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
