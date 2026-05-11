import AppKit
import KeyboardSwitchCore

struct KeyboardSettingsSnapshot {
    let devices: [BluetoothDeviceIdentity]
    let monitoredName: String
    let monitoredAddress: String?
    let statusText: String
}

@MainActor
final class KeyboardSettingsWindowController: NSWindowController {
    private let configuration: KeyboardSwitchConfiguration
    private let diagnostics: KeyboardSwitchDiagnostics
    private let onSave: () -> Void
    private let onOpenLog: () -> Void
    private let snapshotProvider: () -> KeyboardSettingsSnapshot

    private let titleLabel = NSTextField(labelWithString: "Keyboard Switch")
    private let statusLabel = NSTextField(labelWithString: "")
    private let keyboardNameField = NSTextField(string: "")
    private let devicePopupButton = NSPopUpButton()
    private let refreshButton = NSButton(title: "Reload Devices", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let openLogButton = NSButton(title: "Open Log File", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)

    private var availableDevices: [BluetoothDeviceIdentity] = []

    init(
        configuration: KeyboardSwitchConfiguration,
        diagnostics: KeyboardSwitchDiagnostics,
        onSave: @escaping () -> Void,
        onOpenLog: @escaping () -> Void,
        snapshotProvider: @escaping () -> KeyboardSettingsSnapshot
    ) {
        self.configuration = configuration
        self.diagnostics = diagnostics
        self.onSave = onSave
        self.onOpenLog = onOpenLog
        self.snapshotProvider = snapshotProvider

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Switch"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        configureWindow()
        configureActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        devices: [BluetoothDeviceIdentity],
        monitoredName: String,
        monitoredAddress: String?,
        statusText: String
    ) {
        availableDevices = devices
        keyboardNameField.stringValue = monitoredName
        statusLabel.stringValue = statusText
        reloadDevicePopup(selectedName: monitoredName, selectedAddress: monitoredAddress)

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureWindow() {
        guard let contentView = window?.contentView else { return }

        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        keyboardNameField.placeholderString = "Bluetooth keyboard name"

        let keyboardNameLabel = NSTextField(labelWithString: "Monitor this keyboard")
        let popupLabel = NSTextField(labelWithString: "Detected Bluetooth keyboards")

        let buttonsStack = NSStackView(views: [saveButton, openLogButton, quitButton])
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 10
        buttonsStack.distribution = .fillEqually

        let stack = NSStackView(views: [
            titleLabel,
            statusLabel,
            keyboardNameLabel,
            keyboardNameField,
            popupLabel,
            devicePopupButton,
            refreshButton,
            buttonsStack
        ])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        keyboardNameField.translatesAutoresizingMaskIntoConstraints = false
        devicePopupButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            keyboardNameField.widthAnchor.constraint(equalToConstant: 400),
            devicePopupButton.widthAnchor.constraint(equalToConstant: 400),
            refreshButton.widthAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func configureActions() {
        saveButton.target = self
        saveButton.action = #selector(saveSelection)

        openLogButton.target = self
        openLogButton.action = #selector(openLogFile)

        quitButton.target = self
        quitButton.action = #selector(quitApp)

        refreshButton.target = self
        refreshButton.action = #selector(refreshFromPopupSelection)

        devicePopupButton.target = self
        devicePopupButton.action = #selector(selectDetectedDevice)
    }

    private func reloadDevicePopup(selectedName: String, selectedAddress: String?) {
        devicePopupButton.removeAllItems()
        devicePopupButton.addItem(withTitle: "Choose detected keyboard")

        for device in availableDevices {
            let title = device.name ?? device.nameOrAddress ?? "Unknown keyboard"
            devicePopupButton.addItem(withTitle: title)
            if let item = devicePopupButton.itemArray.last {
                item.representedObject = device
            }
        }

        if let matchingIndex = devicePopupButton.itemArray.firstIndex(where: { item in
            guard let device = item.representedObject as? BluetoothDeviceIdentity else { return false }
            return BluetoothTargetResolution.matchesTarget(
                configuredName: selectedName,
                resolvedAddress: selectedAddress,
                candidate: device
            )
        }) {
            devicePopupButton.selectItem(at: matchingIndex)
        } else {
            devicePopupButton.selectItem(at: 0)
        }
    }

    @objc private func selectDetectedDevice() {
        guard
            let device = devicePopupButton.selectedItem?.representedObject as? BluetoothDeviceIdentity,
            let title = device.name ?? device.nameOrAddress
        else {
            return
        }

        keyboardNameField.stringValue = title
    }

    @objc private func refreshFromPopupSelection() {
        diagnostics.info("Settings window reloaded available devices")
        let snapshot = snapshotProvider()
        keyboardNameField.stringValue = snapshot.monitoredName
        statusLabel.stringValue = snapshot.statusText
        availableDevices = snapshot.devices
        reloadDevicePopup(
            selectedName: snapshot.monitoredName,
            selectedAddress: snapshot.monitoredAddress
        )
    }

    @objc private func saveSelection() {
        let selectedDevice = devicePopupButton.selectedItem?.representedObject as? BluetoothDeviceIdentity
        let selectedName = keyboardNameField.stringValue
        let selectedDeviceName = selectedDevice?.name ?? selectedDevice?.nameOrAddress
        let address = selectedDeviceName == selectedName ? selectedDevice?.address : nil
        configuration.saveSelection(name: selectedName, address: address)
        diagnostics.info("Saved monitored keyboard selection: \(configuration.monitoredKeyboardName)")
        onSave()
        window?.orderOut(nil)
    }

    @objc private func openLogFile() {
        onOpenLog()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
