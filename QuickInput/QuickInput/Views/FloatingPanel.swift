import AppKit
import SwiftUI

/// A floating NSPanel that stays above other windows.
/// Used for the quick input interface.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - contentRect.width / 2
            let y = screenFrame.midY - contentRect.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    /// Allow the panel to become key window so the text editor can receive input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            focusTextView()
        }
    }

    private func focusTextView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let textView = self.firstTextView(in: self.contentView) else { return }
            self.makeFirstResponder(textView)
        }
    }

    private func firstTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
    }
}

/// Manages the floating panel lifecycle and hosts a SwiftUI view inside it.
@MainActor
final class FloatingPanelManager: ObservableObject {
    private var panel: FloatingPanel?
    @Published var isVisible = false

    func toggle<Content: View>(@ViewBuilder content: () -> Content) {
        if let panel = panel {
            panel.toggle()
            isVisible = panel.isVisible
        } else {
            let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320))
            panel.contentView = NSHostingView(rootView: content())
            self.panel = panel
            panel.toggle()
            isVisible = true
        }
    }

    func close() {
        panel?.orderOut(nil)
        isVisible = false
    }
}
