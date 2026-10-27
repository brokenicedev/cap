import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController {
    private let appState: AppState
    private var panel: KeyablePanel?
    private var hostingView: ClipboardPanelHostingView<AnyView>?
    private var keyMonitor: Any?
    private var resignKeyObserver: NSObjectProtocol?
    private var isPerformingPaste = false
    private var openedAt: Date?

    init(appState: AppState) {
        self.appState = appState
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggleAnchoredToStatusBar(button: NSStatusBarButton) {
        if isVisible {
            close()
            return
        }
        PasteTargetTracker.captureForPanelOpen()
        show(anchor: .statusBar(button), deferFocus: false)
    }

    func toggleFromHotKey() {
        if isVisible {
            close()
            return
        }
        PasteTargetTracker.captureForHotKey()
        NSApp.activate(ignoringOtherApps: true)
        show(anchor: .cursor, deferFocus: true)
        scheduleFocusRetries()
    }

    func close() {
        panel?.orderOut(nil)
        removeMonitors()
        openedAt = nil
    }

    private enum PanelAnchor {
        case cursor
        case statusBar(NSStatusBarButton)
    }

    private func show(anchor: PanelAnchor, deferFocus: Bool) {
        SettingsWindowController.close()
        let panel = ensurePanel()
        syncPanelMetrics()
        switch anchor {
        case .cursor:
            positionNearMouse(panel)
        case .statusBar(let button):
            positionBelowStatusBar(panel, button: button)
        }
        openedAt = Date()
        appState.prepareForKeyboardNavigation()
        installMonitors()
        panel.makeKeyAndOrderFront(nil)
        if !deferFocus {
            claimKeyboardFocus()
        }
    }

    private func scheduleFocusRetries() {
        for delay in [0.05, 0.12, 0.22, 0.35] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.panel?.isVisible == true else { return }
                self.claimKeyboardFocus()
            }
        }
    }

    private func ensurePanel() -> KeyablePanel {
        if let panel { return panel }
        let root = AnyView(ClipboardPickerView().environmentObject(appState))
        let hosting = ClipboardPanelHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: HistoryPanelMetrics.contentSize)
        hosting.appearance = NSAppearance(named: .darkAqua)
        // Invio/frecce gestiti dal local monitor; evita doppia gestione qui.
        hosting.onKeyDown = { _ in false }
        hostingView = hosting

        let panel = KeyablePanel(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = BuildFlavor.panelTitle
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.contentView = hosting
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        self.panel = panel

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.closeIfResignedOutside() }
        }
        return panel
    }

    private func syncPanelMetrics() {
        let size = HistoryPanelMetrics.contentSize
        hostingView?.setFrameSize(size)
        panel?.setContentSize(size)
    }

    private func claimKeyboardFocus() {
        guard let panel, let hostingView else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(hostingView)
    }

    private func closeIfResignedOutside() {
        guard !isPerformingPaste, let panel, panel.isVisible else { return }
        if let openedAt, Date().timeIntervalSince(openedAt) < 0.45 {
            return
        }
        // Non chiudere se il puntatore è ancora sul pannello (es. ⌘⇧V vicino al cursore + Invio).
        let mouse = NSEvent.mouseLocation
        if panel.frame.contains(mouse) {
            return
        }
        close()
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - panel.frame.height - 12)
        clampOrigin(&origin, panel: panel, near: mouse)
        panel.setFrameOrigin(origin)
    }

    private func positionBelowStatusBar(_ panel: NSPanel, button: NSStatusBarButton) {
        guard let window = button.window else {
            positionNearMouse(panel)
            return
        }
        let buttonOnScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = NSPoint(
            x: buttonOnScreen.midX - panel.frame.width / 2,
            y: buttonOnScreen.minY - panel.frame.height - 4
        )
        clampOrigin(&origin, panel: panel, near: NSPoint(x: buttonOnScreen.midX, y: buttonOnScreen.midY))
        panel.setFrameOrigin(origin)
    }

    private func clampOrigin(_ origin: inout NSPoint, panel: NSPanel, near: NSPoint) {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(near) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - panel.frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - panel.frame.height)
        }
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                if self.panel?.isVisible == true {
                    self.claimKeyboardFocus()
                }
                return event
            }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            if ScopeKeyboardShortcuts.matchesGeneralShortcut(event) {
                appState.selectScope(.general)
                return true
            }
            if let index = ScopeKeyboardShortcuts.matchesGroupIndexShortcut(event) {
                appState.selectScopeKeyboardIndex(index)
                return true
            }
            return false
        }

        switch event.keyCode {
        case 125:
            appState.selectNextClipping()
            return true
        case 126:
            appState.selectPreviousClipping()
            return true
        case 36, 76:
            performPasteSelected()
            return true
        case 53:
            close()
            return true
        default:
            return false
        }
    }

    private func performPasteSelected() {
        guard let id = appState.selectedClippingID,
              let clipping = appState.filteredClippings.first(where: { $0.id == id }) else { return }
        performPaste(clipping)
    }

    func performPaste(_ clipping: ClippingRecord) {
        guard !isPerformingPaste else { return }
        isPerformingPaste = true
        if Preferences.closePanelAfterPaste {
            PasteService.paste(clipping) { [weak self] in
                self?.isPerformingPaste = false
            }
        } else {
            PasteService.writeToPasteboard(clipping)
            isPerformingPaste = false
        }
    }
}
