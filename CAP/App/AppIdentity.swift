import Foundation

enum AppIdentity {
    static let name = "CAP"
    static let bundleIdentifier = "brokenice.it.cap"
    /// Bundle ID precedenti: le preferenze vengono copiate da qui al primo avvio (dal più recente).
    static let legacyBundleIdentifiers = ["com.francesco.CAP", "com.francesco.CopyAndPaste"]
    static let supportDirectoryName = "CAP"
    /// Cartella Application Support del nome app precedente (pre-CAP).
    static let legacySupportDirectoryName = "CopyAndPaste"
}
