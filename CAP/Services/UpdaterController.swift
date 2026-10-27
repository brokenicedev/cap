import AppKit
import Sparkle

/// Aggiornamenti in-app via Sparkle 2 (feed: `SUFeedURL` in Info.plist).
/// Nelle build Debug l'updater non parte, così non propone aggiornamenti durante lo sviluppo.
@MainActor
final class UpdaterController {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: !BuildFlavor.isDebug,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Avvia l'updater (controllo automatico in background secondo le preferenze Sparkle).
    func start() {
        _ = controller
    }

    var isAvailable: Bool { !BuildFlavor.isDebug }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        // App solo menu bar: porta in primo piano la finestra di Sparkle.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    static var currentVersionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
