import AppKit
import SwiftUI

struct KeyRecorderView: NSViewRepresentable {
    @Binding var binding: HotkeyBinding
    var isRecording: Binding<Bool>

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $binding, isRecording: isRecording)
    }

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.coordinator = context.coordinator
        context.coordinator.nsView = view
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.currentBinding = binding
        nsView.isRecording = isRecording.wrappedValue
        // Keep coordinator bindings in sync when SwiftUI recreates the view
        context.coordinator.binding = $binding
        context.coordinator.isRecording = isRecording
        nsView.needsDisplay = true
    }

    @MainActor
    final class Coordinator {
        var binding: Binding<HotkeyBinding>
        var isRecording: Binding<Bool>
        weak var nsView: KeyRecorderNSView?

        init(binding: Binding<HotkeyBinding>, isRecording: Binding<Bool>) {
            self.binding = binding
            self.isRecording = isRecording
        }

        func updateBinding(_ newBinding: HotkeyBinding) {
            binding.wrappedValue = newBinding
        }

        func setRecording(_ recording: Bool) {
            isRecording.wrappedValue = recording
        }
    }
}

final class KeyRecorderNSView: NSView {
    var coordinator: KeyRecorderView.Coordinator?
    var currentBinding: HotkeyBinding = .default
    var isRecording = false
    var currentModifierDisplay = ""
    private nonisolated(unsafe) var eventMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 160, height: 24)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            isRecording = true
            currentModifierDisplay = ""
            coordinator?.setRecording(true)
            window?.makeFirstResponder(self)
            installMonitor()
            needsDisplay = true
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // In recording mode, consume the event to prevent system beep.
        // Actual handling is done by the local event monitor.
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        // In recording mode, consume the event to prevent system beep.
        // Actual handling is done by the local event monitor.
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
    }

    private func handleRecordingKey(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape: cancel recording
        if keyCode == 53 {
            cancelRecording()
            return
        }

        // Delete without modifiers: reset to default
        if keyCode == 51 && flags.intersection([.command, .shift, .option, .control]).isEmpty {
            let defaultBinding = HotkeyBinding.default
            coordinator?.updateBinding(defaultBinding)
            currentBinding = defaultBinding
            cancelRecording()
            return
        }

        // Must have at least ⌘ or ⌃
        let candidate = HotkeyBinding(keyCode: keyCode, nsFlags: flags)
        guard candidate.isValid else { return }

        coordinator?.updateBinding(candidate)
        currentBinding = candidate
        cancelRecording()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifierDisplay = HotkeyBinding.modifierDisplayString(for: flags)
        needsDisplay = true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        handleFlagsChanged(event)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            cancelRecording()
        }
        return super.resignFirstResponder()
    }

    // MARK: - Local Event Monitor

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.type == .flagsChanged {
                self.handleFlagsChanged(event)
                return nil
            }
            self.handleRecordingKey(event)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func cancelRecording() {
        isRecording = false
        currentModifierDisplay = ""
        coordinator?.setRecording(false)
        removeMonitor()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        // Background
        NSColor.controlBackgroundColor.setFill()
        path.fill()

        // Border
        if isRecording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        // Text
        let text: String
        if isRecording {
            text = currentModifierDisplay.isEmpty ? "Type shortcut..." : "\(currentModifierDisplay)..."
        } else {
            text = currentBinding.displayString
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)
    }
}
