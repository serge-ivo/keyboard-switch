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

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}
