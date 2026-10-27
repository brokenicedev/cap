import AppKit
import SwiftUI

enum ClippingThumbnail {
    static func image(for clipping: ClippingRecord, maxPixelSize: CGFloat = 88) -> NSImage? {
        switch clipping.payloadFormat {
        case .png, .tiff:
            guard let source = NSImage(data: clipping.payload) else { return nil }
            return downscaled(source, maxPixelSize: maxPixelSize)
        case .plainText, .rtf, .html:
            return nil
        }
    }

    private static func downscaled(_ image: NSImage, maxPixelSize: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxPixelSize / size.width, maxPixelSize / size.height, 1)
        if scale >= 1 { return image }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        result.unlockFocus()
        return result
    }
}

struct ClippingThumbnailView: View {
    let clipping: ClippingRecord
    /// Altezza del riquadro anteprima in lista.
    var height: CGFloat = 56
    /// Larghezza massima (screenshot larghi restano leggibili).
    var maxWidth: CGFloat = 88

    var body: some View {
        if let nsImage = ClippingThumbnail.image(for: clipping, maxPixelSize: max(height, maxWidth) * 2.5) {
            let fitted = Self.fittedSize(
                imageSize: nsImage.size,
                maxWidth: maxWidth,
                maxHeight: height
            )
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.1))

                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fitted.width, height: fitted.height)
            }
            .frame(width: max(fitted.width + 8, height * 0.85), height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
    }

    private static func fittedSize(imageSize: NSSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: maxWidth, height: maxHeight)
        }
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

extension ClippingRecord {
    var showsImagePreview: Bool {
        switch payloadFormat {
        case .png, .tiff: return ClippingThumbnail.image(for: self) != nil
        default: return false
        }
    }
}
