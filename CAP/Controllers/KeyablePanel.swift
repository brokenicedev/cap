import AppKit
import SwiftUI

/// Pannello che accetta il focus tastiera (necessario per frecce e Invio).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosting SwiftUI che intercetta `keyDown` prima della List.
final class ClipboardPanelHostingView<Content: View>: NSHostingView<Content> {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
