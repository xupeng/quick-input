import AppKit
import Carbon

struct HotkeyBinding: Codable, Sendable, Equatable {
    var keyCode: UInt16
    var modifiers: ModifierFlags

    static let `default` = HotkeyBinding(keyCode: 45, modifiers: [.command, .shift]) // ⌘⇧N

    struct ModifierFlags: OptionSet, Codable, Sendable, Hashable {
        let rawValue: UInt8
        static let control = ModifierFlags(rawValue: 1 << 0)
        static let option = ModifierFlags(rawValue: 1 << 1)
        static let shift = ModifierFlags(rawValue: 1 << 2)
        static let command = ModifierFlags(rawValue: 1 << 3)
    }

    var isValid: Bool {
        modifiers.contains(.command) || modifiers.contains(.control)
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    func matches(flags: CGEventFlags, keyCode: Int64) -> Bool {
        guard self.keyCode == UInt16(keyCode) else { return false }

        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasOption = flags.contains(.maskAlternate)
        let hasControl = flags.contains(.maskControl)

        return hasCommand == modifiers.contains(.command)
            && hasShift == modifiers.contains(.shift)
            && hasOption == modifiers.contains(.option)
            && hasControl == modifiers.contains(.control)
    }

    init(keyCode: UInt16, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(keyCode: UInt16, nsFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        var mods = ModifierFlags()
        if nsFlags.contains(.command) { mods.insert(.command) }
        if nsFlags.contains(.shift) { mods.insert(.shift) }
        if nsFlags.contains(.option) { mods.insert(.option) }
        if nsFlags.contains(.control) { mods.insert(.control) }
        self.modifiers = mods
    }

    static func modifierDisplayString(for nsFlags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if nsFlags.contains(.control) { parts.append("⌃") }
        if nsFlags.contains(.option) { parts.append("⌥") }
        if nsFlags.contains(.shift) { parts.append("⇧") }
        if nsFlags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    // MARK: - Key Name Lookup

    private static let specialKeys: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        76: "⌤", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15",
        115: "Home", 116: "⇞", 117: "⌦", 118: "F4",
        119: "End", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeys[keyCode] {
            return special
        }
        return ucKeyTranslateName(for: keyCode)
    }

    private static func ucKeyTranslateName(for keyCode: UInt16) -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutDataPtr = TISGetInputSourceProperty(
            source,
            kTISPropertyUnicodeKeyLayoutData
        ) else {
            return "Key\(keyCode)"
        }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self) as Data
        return layoutData.withUnsafeBytes { rawBuffer -> String in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return "Key\(keyCode)"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0

            let status = UCKeyTranslate(
                ptr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )

            guard status == noErr, length > 0 else { return "Key\(keyCode)" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
