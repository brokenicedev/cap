import AppKit

/// Tiene traccia dell’ultima app utente (non CAP) per incollare dopo ⌘⇧V o pannello.
@MainActor
enum PasteTargetTracker {
    private static var lastUserPID: pid_t?
    private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                rememberUserApp(app)
            }
        }
    }

    static func captureForHotKey() {
        if let front = NSWorkspace.shared.frontmostApplication, isUserApp(front) {
            rememberUserApp(front)
            return
        }
        restoreLastKnownToCoordinator()
    }

    static func captureForPanelOpen() {
        if let front = NSWorkspace.shared.frontmostApplication, isUserApp(front) {
            rememberUserApp(front)
            return
        }
        restoreLastKnownToCoordinator()
    }

    static func resolvedTarget() -> NSRunningApplication? {
        if let fromCoordinator = AppCoordinator.resolvedPasteTarget() {
            return fromCoordinator
        }
        return runningApp(for: lastUserPID)
    }

    private static func rememberUserApp(_ app: NSRunningApplication) {
        guard isUserApp(app) else { return }
        lastUserPID = app.processIdentifier
        AppCoordinator.storePasteTarget(app)
    }

    private static func restoreLastKnownToCoordinator() {
        guard let app = runningApp(for: lastUserPID) else { return }
        AppCoordinator.storePasteTarget(app)
    }

    private static func isUserApp(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier != Bundle.main.bundleIdentifier && !app.isTerminated
    }

    private static func runningApp(for pid: pid_t?) -> NSRunningApplication? {
        guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            return nil
        }
        return app
    }
}
