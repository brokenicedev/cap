import AppKit
import CoreGraphics

enum HistoryPanelMetrics {
    /// Finestra flottante cronologia (proporzioni compatte, stile clipboard manager).
    static let width: CGFloat = 520
    /// Altezza totale del pannello (header + lista scrollabile + toolbar).
    static let height: CGFloat = 228

    static var contentSize: NSSize {
        NSSize(width: width, height: height)
    }
}
