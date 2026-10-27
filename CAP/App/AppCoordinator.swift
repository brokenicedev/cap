import AppKit
import Foundation

@MainActor
enum AppCoordinator {
    static weak var appState: AppState?
    static weak var historyPanel: HistoryPanelController?

    /// App che aveva il focus prima di aprire il pannello (es. campo di testo).
    static var pasteTargetApp: NSRunningApplication?
    private static var pasteTargetPID: pid_t?

    static func closeAllPanels() {
        historyPanel?.close()
    }

    static var pastePanel: HistoryPanelController? { historyPanel }

    static func capturePasteTargetIfNeeded() {
        PasteTargetTracker.captureForPanelOpen()
    }

    static func storePasteTarget(_ app: NSRunningApplication) {
        pasteTargetApp = app
        pasteTargetPID = app.processIdentifier
    }

    /// Risolve l’app target anche se l’istanza `NSRunningApplication` è stata ricreata.
    static func resolvedPasteTarget() -> NSRunningApplication? {
        if let pid = pasteTargetPID,
           let app = NSRunningApplication(processIdentifier: pid),
           !app.isTerminated {
            return app
        }
        if let app = pasteTargetApp, !app.isTerminated {
            return app
        }
        return nil
    }
}
