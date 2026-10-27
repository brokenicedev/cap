import AppKit
import Foundation
import UniformTypeIdentifiers

final class PasteboardMonitor {
    private let onChange: (PasteboardSnapshot) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general, onChange: @escaping (PasteboardSnapshot) -> Void) {
        self.pasteboard = pasteboard
        self.onChange = onChange
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if PasteService.shouldSuppressCapture { return }

        guard let snapshot = readSnapshot() else { return }
        if snapshot.isEffectivelyEmpty { return }
        onChange(snapshot)
    }

    private func readSnapshot() -> PasteboardSnapshot? {
        let types = pasteboard.types ?? []
        let plain = pasteboard.string(forType: .string)
        let rtf = pasteboard.data(forType: .rtf)
        let html = pasteboard.data(forType: .html)

        var imageData: Data?
        var imageUTI: String?
        if let png = pasteboard.data(forType: .png) {
            imageData = png
            imageUTI = UTType.png.identifier
        } else if let tiff = pasteboard.data(forType: .tiff) {
            imageData = tiff
            imageUTI = UTType.tiff.identifier
        } else if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
                  let image = objects.first as? NSImage,
                  let tiff = image.tiffRepresentation {
            imageData = tiff
            imageUTI = UTType.tiff.identifier
        }

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let title = plain?.split(separator: "\n").first.map(String.init)

        return PasteboardSnapshot(
            plainText: plain,
            rtfData: rtf,
            htmlData: html,
            imageData: imageData,
            imageUTI: imageUTI,
            sourceBundleID: bundleID,
            suggestedTitle: title
        )
    }
}

private extension PasteboardSnapshot {
    var isEffectivelyEmpty: Bool {
        let hasText = !(plainText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasRich = rtfData != nil || htmlData != nil
        let hasImage = imageData != nil
        return !hasText && !hasRich && !hasImage
    }
}
