import Cocoa

class KeyboardMonitor: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    let deviceName = "MK550KB"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        updateStatus()

        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    func updateStatus() {
        DispatchQueue.global(qos: .utility).async { [self] in
            let connected = isDeviceConnected()
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.createDotImage(connected: connected)
            }
        }
    }

    func createDotImage(connected: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dotRect = NSRect(x: 3, y: 3, width: 12, height: 12)
            let color: NSColor = connected ? .systemGreen : .systemGray
            color.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    func isDeviceConnected() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return false }

        let lines = output.components(separatedBy: "\n")
        var inConnected = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Connected:" {
                inConnected = true
                continue
            }
            if trimmed == "Not Connected:" {
                inConnected = false
                continue
            }
            if inConnected && trimmed.contains(deviceName) {
                return true
            }
        }
        return false
    }
}

let app = NSApplication.shared
let delegate = KeyboardMonitor()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
