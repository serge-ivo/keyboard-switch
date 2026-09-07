import Foundation
import IOKit

/// Notifies when any HID device is attached to or removed from this Mac.
///
/// Bluetooth keyboards — BLE included — surface as `IOHIDDevice` services while
/// connected, so matched/terminated notifications tell us exactly when to
/// re-check the keyboard, instead of polling on a timer. We only observe the
/// registry; the device is never opened and no input is read, so this needs no
/// Input Monitoring permission.
final class HIDPresenceWatcher {
    private let notificationPort: IONotificationPortRef
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private let onChange: () -> Void

    /// - Parameter onChange: called on the main queue when any HID device is
    ///   added or removed. It fires for every HID device, not only the
    ///   monitored keyboard, so the caller re-checks which one it cares about.
    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(notificationPort, DispatchQueue.main)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refCon, iterator in
            HIDPresenceWatcher.drain(iterator)
            guard let refCon else { return }
            Unmanaged<HIDPresenceWatcher>.fromOpaque(refCon)
                .takeUnretainedValue()
                .onChange()
        }

        // IOServiceAddMatchingNotification consumes the matching dictionary, so
        // each registration needs its own copy.
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOMatchedNotification,
            IOServiceMatching(kIOHIDDeviceKey),
            callback,
            context,
            &matchedIterator
        )
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            IOServiceMatching(kIOHIDDeviceKey),
            callback,
            context,
            &terminatedIterator
        )

        // Each iterator must be drained once to arm it; an undrained iterator
        // never delivers another notification.
        Self.drain(matchedIterator)
        Self.drain(terminatedIterator)
    }

    deinit {
        IOObjectRelease(matchedIterator)
        IOObjectRelease(terminatedIterator)
        IONotificationPortDestroy(notificationPort)
    }

    /// Whether a HID device with this `Product` string is attached right now.
    ///
    /// This is the connection state, read straight from the registry: the
    /// device is present exactly while the link is up. It replaces querying the
    /// Bluetooth controller, which is the one thing we must not do on the
    /// disconnect path — the keyboard is reconnecting at that moment, and
    /// interrogating the controller mid-handshake is a suspect in the garbled
    /// first keystrokes after a wake.
    static func isPresent(productName: String) -> Bool {
        let target = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDDeviceKey),
            &iterator
        ) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        var found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            if !found,
               let product = IORegistryEntryCreateCFProperty(
                   service, kIOHIDProductKey as CFString, kCFAllocatorDefault, 0
               )?.takeRetainedValue() as? String,
               product == target {
                found = true
            }
            IOObjectRelease(service)
        }
        return found
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}
