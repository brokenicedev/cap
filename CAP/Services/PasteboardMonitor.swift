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
        let fileURLs = readFileURLs(from: types)

        let plain = pasteboard.string(forType: .string)
        let rtf = pasteboard.data(forType: .rtf)
        let html = pasteboard.data(forType: .html)

        var imageData: Data?
        var imageUTI: String?
        if fileURLs == nil {
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
        }

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let fileLabel = fileURLs.map { FileClipboardSupport.displayLabel(for: $0) }
        let title = fileLabel ?? plain?.split(separator: "\n").first.map(String.init)
        let plainForRecord = fileLabel ?? plain

        return PasteboardSnapshot(
            plainText: plainForRecord,
            rtfData: fileURLs == nil ? rtf : nil,
            htmlData: fileURLs == nil ? html : nil,
            imageData: imageData,
            imageUTI: imageUTI,
            fileURLs: fileURLs,
            sourceBundleID: bundleID,
            suggestedTitle: title
        )
    }

    private func readFileURLs(from types: [NSPasteboard.PasteboardType]) -> [URL]? {
        let hasFileURL = types.contains { type in
            type == .fileURL || type.rawValue == UTType.fileURL.identifier
        }
        guard hasFileURL else { return nil }

        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !objects.isEmpty else {
            return nil
        }
        return objects
    }
}

private extension PasteboardSnapshot {
    var isEffectivelyEmpty: Bool {
        let hasFiles = !(fileURLs?.isEmpty ?? true)
        let hasText = !(plainText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasRich = rtfData != nil || htmlData != nil
        let hasImage = imageData != nil
        return !hasFiles && !hasText && !hasRich && !hasImage
    }
}
