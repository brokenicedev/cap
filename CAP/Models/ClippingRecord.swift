import Foundation

struct ClippingRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var title: String?
    let plainText: String?
    let payload: Data
    let payloadFormat: PayloadFormat
    let sourceBundleID: String?
    var isStarred: Bool
    /// `nil` = visibile in Generale.
    var groupId: UUID?

    /// Breve etichetta (es. ricerca compatta): prima riga o anteprima su una riga.
    var displayTitle: String {
        if let plainText, !plainText.isEmpty {
            let firstLine = plainText
                .replacingOccurrences(of: "\r\n", with: "\n")
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? plainText
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let title, !title.isEmpty { return title }
        return plainTextPreview
    }

    /// Anteprima nella lista: mantiene gli a capo come nel contenuto copiato.
    var listPreviewText: String {
        guard let plainText, !plainText.isEmpty else {
            switch payloadFormat {
            case .png, .tiff: return "Immagine"
            case .rtf: return "Testo formattato"
            case .html: return "HTML"
            case .plainText: return "Vuoto"
            }
        }

        let normalized = plainText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let maxLines = 8
        var previewLines = Array(lines.prefix(maxLines))
        if lines.count > maxLines {
            previewLines.append("…")
        }
        var joined = previewLines.joined(separator: "\n")
        let maxChars = 900
        if joined.count > maxChars {
            joined = String(joined.prefix(maxChars - 1)) + "…"
        }
        return joined
    }

    var plainTextPreview: String {
        guard let plainText, !plainText.isEmpty else {
            switch payloadFormat {
            case .png, .tiff: return "Image"
            case .rtf: return "Rich text"
            case .html: return "HTML"
            case .plainText: return "Empty"
            }
        }
        let singleLine = plainText.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count <= 120 { return singleLine }
        return String(singleLine.prefix(117)) + "…"
    }
}

enum PayloadFormat: String, Codable, Sendable {
    case plainText
    case rtf
    case html
    case png
    case tiff
}

struct PasteboardSnapshot: Sendable {
    let plainText: String?
    let rtfData: Data?
    let htmlData: Data?
    let imageData: Data?
    let imageUTI: String?
    let sourceBundleID: String?
    let suggestedTitle: String?
}
