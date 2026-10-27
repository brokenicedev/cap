import ApplicationServices
import AppKit

enum AccessibilityAuthorization {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var runningAppName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? AppIdentity.name
    }

    static var bundleURL: URL {
        Bundle.main.bundleURL
    }

    /// Apre Finder sulla .app e Impostazioni → Accessibilità (senza dialoghi di sistema).
    static func openRegistrationAssistant() {
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
        openSystemSettings()
    }

    static func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }

    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
