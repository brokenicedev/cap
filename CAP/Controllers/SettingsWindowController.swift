import AppKit
import SwiftUI

@MainActor
enum SettingsWindowController {
    private static var window: NSWindow?
    private static var outsideClickMonitor: Any?

    static var isVisible: Bool {
        window?.isVisible == true
    }

    static func show() {
        AppCoordinator.closeAllPanels()
        guard let appState = AppCoordinator.appState else { return }
        let hosting = NSHostingController(
            rootView: PreferencesView().environmentObject(appState)
        )
        if let window {
            window.contentViewController = hosting
        } else {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Impostazioni \(BuildFlavor.menuBarAccessibilityLabel)"
            newWindow.contentViewController = hosting
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()
    }

    static func close() {
        window?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    private static func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            Task { @MainActor in closeIfClickOutside() }
        }
    }

    private static func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private static func closeIfClickOutside() {
        guard let window, window.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        if !window.frame.contains(mouse) {
            close()
        }
    }
}
