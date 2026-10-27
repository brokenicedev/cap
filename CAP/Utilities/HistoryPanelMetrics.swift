import AppKit
import CoreGraphics

enum HistoryPanelMetrics {
    /// Finestra flottante cronologia (proporzioni compatte, stile clipboard manager).
    static let width: CGFloat = 520
    /// Altezza totale del pannello (header + lista scrollabile + toolbar).
    static let height: CGFloat = 228

    /// Dimensione minima consentita durante il ridimensionamento.
    static let minWidth: CGFloat = 420
    static let minHeight: CGFloat = 180

    private static let savedSizeKey = "historyPanelContentSize"

    static var defaultContentSize: NSSize {
        NSSize(width: width, height: height)
    }

    static var minContentSize: NSSize {
        NSSize(width: minWidth, height: minHeight)
    }

    /// Ultima dimensione scelta dall'utente (o quella di default).
    static var contentSize: NSSize {
        guard let raw = UserDefaults.standard.string(forKey: savedSizeKey) else {
            return defaultContentSize
        }
        let size = NSSizeFromString(raw)
        guard size.width >= minWidth, size.height >= minHeight else {
            return defaultContentSize
        }
        return size
    }

    static func saveContentSize(_ size: NSSize) {
        UserDefaults.standard.set(NSStringFromSize(size), forKey: savedSizeKey)
    }
}
