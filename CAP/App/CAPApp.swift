import SwiftUI

@main
struct CAPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    /// Scene minima: le impostazioni si aprono solo da `SettingsWindowController`.
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyService: GlobalHotKeyService?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.migrateFromLegacyBundleIfNeeded()
        Task { @MainActor [weak self] in
            self?.wireServices()
        }
    }

    @MainActor
    private func wireServices() {
        guard let appState = AppCoordinator.appState else { return }

        PasteTargetTracker.start()

        let historyPanel = HistoryPanelController(appState: appState)
        AppCoordinator.historyPanel = historyPanel

        let statusBar = StatusBarController(appState: appState, historyPanel: historyPanel)
        statusBar.install()
        statusBarController = statusBar

        hotKeyService = GlobalHotKeyService {
            Task { @MainActor in
                PasteTargetTracker.captureForHotKey()
                AppCoordinator.historyPanel?.toggleFromHotKey()
            }
        }
        hotKeyService?.register()
    }
}
