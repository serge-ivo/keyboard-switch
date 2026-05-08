import AVFoundation
import ApplicationServices
import Carbon
import Cocoa
import KeyboardSwitchCore
import Speech

private let promptWhisperHotKeyID: UInt32 = 1
private let promptWhisperHotKeySignature: OSType = 0x50575250 // PWRP

enum PromptWhisperError: LocalizedError {
    case accessibilityNotTrusted
    case focusedElementUnavailable
    case microphonePermissionDenied
    case speechPermissionDenied
    case speechRecognizerUnavailable
    case failedToRefocusTarget
    case emptyTranscript
    case unableToCreateEvent

    var errorDescription: String? {
        switch self {
        case .accessibilityNotTrusted:
            return "Accessibility access is required to refocus the original text box."
        case .focusedElementUnavailable:
            return "No editable focused text box was captured."
        case .microphonePermissionDenied:
            return "Microphone permission is required."
        case .speechPermissionDenied:
            return "Speech recognition permission is required."
        case .speechRecognizerUnavailable:
            return "Speech recognition is currently unavailable."
        case .failedToRefocusTarget:
            return "The original text box could not be re-focused, so nothing was pasted."
        case .emptyTranscript:
            return "No speech was transcribed."
        case .unableToCreateEvent:
            return "Could not synthesize the paste or Return key event."
        }
    }
}

struct FocusedTextTarget {
    let appPID: pid_t
    let element: AXUIElement
}

struct PasteboardSnapshot {
    let string: String?

    static func capture() -> PasteboardSnapshot {
        PasteboardSnapshot(string: NSPasteboard.general.string(forType: .string))
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let string {
            pasteboard.setString(string, forType: .string)
        }
    }
}

@MainActor
final class PromptWhisperApp: NSObject, NSApplicationDelegate {
    private let transcriber = DictationTranscriber()
    private let hotKey = GlobalHotKeyController()
    private let submissionPolicy = PromptSubmissionPolicy.strictPrompting

    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!
    private var lastError: String?
    private var capturedTarget: FocusedTextTarget?
    private var isRecording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        toggleMenuItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
        toggleMenuItem.target = self

        let menu = NSMenu()
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        hotKey.onPressed = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
        hotKey.register()

        updateStatusAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.unregister()
    }

    @objc private func toggleRecordingFromMenu() {
        Task { @MainActor in
            await toggleRecording()
        }
    }

    private func updateStatusAppearance() {
        guard let button = statusItem.button else { return }

        let color: NSColor = isRecording ? .systemRed : .white
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = makeStatusDotImage(fillColor: color)
        let baseToolTip = isRecording
            ? "PromptWhisper recording. Press F12 to stop."
            : "PromptWhisper idle. Press F12 to start."
        button.toolTip = lastError.map { "\(baseToolTip)\nLast error: \($0)" } ?? baseToolTip
        toggleMenuItem.title = isRecording ? "Stop Recording" : "Start Recording"
    }

    private func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            try requestAccessibilityIfNeeded()
            capturedTarget = try FocusTargetController.captureFocusedTextTarget()
            try await transcriber.start()
            isRecording = true
            lastError = nil
            playStateChangeSound(starting: true)
            updateStatusAppearance()
        } catch {
            capturedTarget = nil
            isRecording = false
            handle(error)
        }
    }

    private func stopRecording() async {
        isRecording = false
        updateStatusAppearance()

        do {
            let transcript = try await transcriber.stop()
            guard let target = capturedTarget else {
                throw PromptWhisperError.focusedElementUnavailable
            }
            try await FocusTargetController.submit(
                transcript: transcript,
                to: target,
                policy: submissionPolicy
            )
            lastError = nil
            playStateChangeSound(starting: false)
        } catch {
            handle(error)
        }

        capturedTarget = nil
        updateStatusAppearance()
    }

    private func handle(_ error: Error) {
        lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        NSSound.beep()
        updateStatusAppearance()
    }

    private func playStateChangeSound(starting: Bool) {
        NSSound.beep()
        guard !starting else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            NSSound.beep()
        }
    }

    private func requestAccessibilityIfNeeded() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw PromptWhisperError.accessibilityNotTrusted
        }
    }

    private func makeStatusDotImage(fillColor: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let dotRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let path = NSBezierPath(ovalIn: dotRect)
        fillColor.setFill()
        path.fill()

        NSColor.black.withAlphaComponent(0.65).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

@MainActor
enum FocusTargetController {
    static func captureFocusedTextTarget() throws -> FocusedTextTarget {
        let systemElement = AXUIElementCreateSystemWide()

        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedError == .success, let element = focusedValue else {
            throw PromptWhisperError.focusedElementUnavailable
        }

        let targetElement = unsafeDowncast(element as AnyObject, to: AXUIElement.self)

        var pid: pid_t = 0
        AXUIElementGetPid(targetElement, &pid)
        guard pid != 0 else {
            throw PromptWhisperError.focusedElementUnavailable
        }

        return FocusedTextTarget(appPID: pid, element: targetElement)
    }

    static func submit(
        transcript: String,
        to target: FocusedTextTarget,
        policy: PromptSubmissionPolicy
    ) async throws {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            throw PromptWhisperError.emptyTranscript
        }

        let snapshot = PasteboardSnapshot.capture()
        if policy.requiresOriginalFocusedElement {
            let refocused = await refocus(target)
            guard refocused else {
                throw PromptWhisperError.failedToRefocusTarget
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(trimmedTranscript, forType: .string)

        try postCommandV()
        try await Task.sleep(nanoseconds: 150_000_000)

        if policy.submissionKey == .return {
            try postReturn()
        }

        if policy.restoresClipboard {
            try await Task.sleep(nanoseconds: 150_000_000)
            snapshot.restore()
        }
    }

    private static func refocus(_ target: FocusedTextTarget) async -> Bool {
        if let app = NSRunningApplication(processIdentifier: target.appPID) {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        for _ in 0..<8 {
            _ = AXUIElementSetAttributeValue(
                target.element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            )
            try? await Task.sleep(nanoseconds: 100_000_000)
            if currentFocusedElementMatches(target.element) {
                return true
            }
        }

        return false
    }

    private static func currentFocusedElementMatches(_ expectedElement: AXUIElement) -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var currentValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &currentValue
        )
        guard result == .success, let currentValue else {
            return false
        }

        let currentElement = unsafeDowncast(currentValue as AnyObject, to: AXUIElement.self)
        return CFEqual(currentElement, expectedElement)
    }

    private static func postCommandV() throws {
        let flags: CGEventFlags = .maskCommand
        try postKeyPress(keyCode: UInt16(kVK_ANSI_V), flags: flags)
    }

    private static func postReturn() throws {
        try postKeyPress(keyCode: UInt16(kVK_Return), flags: [])
    }

    private static func postKeyPress(keyCode: UInt16, flags: CGEventFlags) throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw PromptWhisperError.unableToCreateEvent
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

@MainActor
final class DictationTranscriber {
    private static let partialTranscriptFallbackDelay: UInt64 = 250_000_000
    private static let emptyTranscriptFallbackDelay: UInt64 = 900_000_000

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var latestTranscript = ""
    private var isStopping = false
    private var stopContinuation: CheckedContinuation<String, Error>?
    private var stopFallbackTask: Task<Void, Never>?

    func start() async throws {
        try await requestPermissions()

        let recognizer = SFSpeechRecognizer(locale: .current)
        guard let recognizer, recognizer.isAvailable else {
            throw PromptWhisperError.speechRecognizerUnavailable
        }

        cancel()
        latestTranscript = ""
        isStopping = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        self.audioEngine = audioEngine
        self.recognitionRequest = request
        self.speechRecognizer = recognizer
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let transcript = result?.bestTranscription.formattedString {
                    self.latestTranscript = transcript
                }

                if let error {
                    self.resolveStopContinuation(with: .failure(error))
                    return
                }

                if result?.isFinal == true {
                    self.resolveStopContinuation(with: .success(self.latestTranscript))
                } else if self.isStopping, !self.latestTranscript.isEmpty {
                    self.resolveStopContinuation(with: .success(self.latestTranscript))
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() async throws -> String {
        guard let audioEngine, let request = recognitionRequest else {
            throw PromptWhisperError.emptyTranscript
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.stopContinuation = continuation
            self.isStopping = true

            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            request.endAudio()

            stopFallbackTask?.cancel()
            let fallbackDelay = latestTranscript.isEmpty
                ? Self.emptyTranscriptFallbackDelay
                : Self.partialTranscriptFallbackDelay
            stopFallbackTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: fallbackDelay)
                self.resolveStopContinuation(with: .success(self.latestTranscript))
            }
        }
    }

    private func resolveStopContinuation(with result: Result<String, Error>) {
        guard let stopContinuation else { return }
        self.stopContinuation = nil
        isStopping = false
        stopFallbackTask?.cancel()
        stopFallbackTask = nil

        switch result {
        case .success(let transcript):
            stopContinuation.resume(returning: transcript)
        case .failure(let error):
            stopContinuation.resume(throwing: error)
        }
    }

    private func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isStopping = false
        stopContinuation = nil
        stopFallbackTask?.cancel()
        stopFallbackTask = nil
    }

    private func requestPermissions() async throws {
        guard await microphonePermissionGranted() else {
            throw PromptWhisperError.microphonePermissionDenied
        }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized else {
            throw PromptWhisperError.speechPermissionDenied
        }
    }

    private func microphonePermissionGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
}

final class GlobalHotKeyController {
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard
                    let userData,
                    let eventRef
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard
                    hotKeyID.signature == promptWhisperHotKeySignature,
                    hotKeyID.id == promptWhisperHotKeyID
                else {
                    return noErr
                }

                let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                controller.onPressed?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(
            signature: promptWhisperHotKeySignature,
            id: promptWhisperHotKeyID
        )

        RegisterEventHotKey(
            UInt32(kVK_F12),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

let app = NSApplication.shared
let delegate = PromptWhisperApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
