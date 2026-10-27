import AppKit
import SwiftUI

enum HexColorParsing {
    /// Colore se l’intero contenuto testuale è un hex (`#RGB`, `#RRGGBB`, `#RRGGBBAA`).
    static func swiftUIColor(from text: String) -> Color? {
        guard let ns = nsColor(from: text) else { return nil }
        return Color(nsColor: ns)
    }

    static func nsColor(from text: String) -> NSColor? {
        guard let hex = normalizedHex(from: text) else { return nil }
        return colorFromHexDigits(hex)
    }

    private static func normalizedHex(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n") else { return nil }

        var token = trimmed
        if token.hasPrefix("#") {
            token.removeFirst()
        } else if token.lowercased().hasPrefix("0x") {
            token.removeFirst(2)
        } else if token.count == 3 || token.count == 6 || token.count == 8 {
            // es. `1677ff` senza #
        } else {
            return nil
        }

        guard token.count == 3 || token.count == 6 || token.count == 8 else { return nil }
        let hexDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard token.unicodeScalars.allSatisfy({ hexDigits.contains($0) }) else { return nil }

        if token.count == 3 {
            token = token.map { String($0) + String($0) }.joined()
        }
        return token.uppercased()
    }

    private static func colorFromHexDigits(_ hex: String) -> NSColor? {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        guard scanner.scanHexInt64(&value) else { return nil }

        let r, g, b, a: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = CGFloat((value & 0xFF000000) >> 24) / 255
            g = CGFloat((value & 0x00FF0000) >> 16) / 255
            b = CGFloat((value & 0x0000FF00) >> 8) / 255
            a = CGFloat(value & 0x000000FF) / 255
        default:
            return nil
        }

        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

struct ClippingColorSwatch: View {
    let color: Color
    var size: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
            )
    }
}

extension ClippingRecord {
    var listHexColor: Color? {
        guard let plainText else { return nil }
        return HexColorParsing.swiftUIColor(from: plainText)
    }
}
