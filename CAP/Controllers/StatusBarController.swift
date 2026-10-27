import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    private let historyPanel: HistoryPanelController
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, historyPanel: HistoryPanelController) {
        self.appState = appState
        self.historyPanel = historyPanel
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        guard let button = item.button else { return }
        historyPanel.statusBarButton = button
        button.target = self
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
        appState.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        let symbol = appState.isRecording ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let image = MenuBarIconFactory.make(symbolName: symbol, debugStripe: BuildFlavor.isDebug)
        statusItem?.button?.image = image
        statusItem?.button?.image?.isTemplate = !BuildFlavor.isDebug
        statusItem?.button?.setAccessibilityLabel(BuildFlavor.menuBarAccessibilityLabel)
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(for: sender)
            return
        }
        historyPanel.toggleAnchoredToStatusBar(button: sender)
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        let settings = NSMenuItem(
            title: "Impostazioni…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)
        if UpdaterController.shared.isAvailable {
            let updates = NSMenuItem(
                title: "Controlla aggiornamenti…",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            )
            updates.target = self
            menu.addItem(updates)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Esci da \(BuildFlavor.menuBarAccessibilityLabel)",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openSettings() {
        SettingsWindowController.show()
    }

    @objc private func checkForUpdates() {
        UpdaterController.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
