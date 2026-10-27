import AppKit
import SwiftUI

struct ClipboardGroup: Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int

    var swiftUIColor: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    static let defaultPalette = [
        "#5AC8FA", "#34C759", "#FF9500", "#FF2D55",
        "#AF52DE", "#FFD60A", "#64D2FF", "#FF6482", "#30B0C7"
    ]

    static func defaultColor(forOrder index: Int) -> String {
        defaultPalette[index % defaultPalette.count]
    }
}

extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    var hexRGB: String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
