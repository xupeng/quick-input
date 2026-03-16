import AppKit
import Carbon

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    private nonisolated(unsafe) var eventTap: CFMachPort?
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    var onHotkey: (@Sendable @MainActor () -> Void)?

    @Published var isAccessibilityGranted = false
    @Published var isRecordingHotkey = false

    private static let userDefaultsKey = "globalHotkeyBinding"

    // Shadow properties for CGEventTap callback (runs off main actor)
    private nonisolated(unsafe) var _bindingKeyCode: UInt16 = HotkeyBinding.default.keyCode
    private nonisolated(unsafe) var _bindingModifiers: HotkeyBinding.ModifierFlags = HotkeyBinding.default.modifiers
    private nonisolated(unsafe) var _isRecording: Bool = false

    @Published var binding: HotkeyBinding = .default {
        didSet {
            _bindingKeyCode = binding.keyCode
            _bindingModifiers = binding.modifiers
            saveBinding()
        }
    }

    init() {
        loadBinding()
        checkAccessibility()
    }

    private func loadBinding() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data)
        else { return }
        binding = decoded
        _bindingKeyCode = decoded.keyCode
        _bindingModifiers = decoded.modifiers
    }

    private func saveBinding() {
        guard let data = try? JSONEncoder().encode(binding) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    @discardableResult
    func checkAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt"
        let trusted = AXIsProcessTrustedWithOptions(
            [key: false] as CFDictionary
        )
        isAccessibilityGranted = trusted
        return trusted
    }

    func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt"
        AXIsProcessTrustedWithOptions(
            [key: true] as CFDictionary
        )
        // Poll for changes after user grants permission
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(1))
                if checkAccessibility() {
                    start()
                    break
                }
            }
        }
    }

    func setRecording(_ recording: Bool) {
        isRecordingHotkey = recording
        _isRecording = recording
    }

    func start() {
        guard isAccessibilityGranted, eventTap == nil else { return }

        let callback: CGEventTapCallBack = { _, _, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            // Skip interception while recording a new hotkey
            if manager._isRecording {
                return Unmanaged.passUnretained(event)
            }

            if event.type == .keyDown {
                let flags = event.flags
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                let bindingToMatch = HotkeyBinding(
                    keyCode: manager._bindingKeyCode,
                    modifiers: manager._bindingModifiers
                )

                if bindingToMatch.matches(flags: flags, keyCode: keyCode) {
                    DispatchQueue.main.async { [weak manager] in
                        manager?.onHotkey?()
                    }
                    return nil // consume the event
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }

    deinit {
        // stop() cannot be called directly from deinit of a @MainActor class,
        // but the event tap and run loop source will be cleaned up when deallocated.
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
    }
}
