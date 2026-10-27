import AppKit

enum MenuBarIconFactory {
    static func make(symbolName: String, debugStripe: Bool) -> NSImage? {
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        guard debugStripe else {
            base.isTemplate = true
            return base
        }

        let pointSize: CGFloat = 18
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return nil
        }

        let canvas = NSSize(width: pointSize + 2, height: pointSize + 4)
        let image = NSImage(size: canvas)
        image.lockFocus()
        let symbolRect = NSRect(x: 1, y: 3, width: pointSize, height: pointSize)
        symbol.draw(in: symbolRect)

        NSColor(red: 1, green: 0.78, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvas.width, height: 3)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
