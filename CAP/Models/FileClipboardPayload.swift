import Foundation
import UniformTypeIdentifiers

struct FileClipboardPayload: Codable, Sendable {
    let paths: [String]

    var fileURLs: [URL] {
        paths.map { URL(fileURLWithPath: $0) }
    }

    static func encode(urls: [URL]) -> Data {
        let payload = FileClipboardPayload(paths: urls.map(\.path))
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }

    static func decode(from data: Data) -> FileClipboardPayload? {
        try? JSONDecoder().decode(FileClipboardPayload.self, from: data)
    }
}

enum FileClipboardSupport {
    static func isImageFile(at url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    static func existingURLs(from payload: Data) -> [URL] {
        guard let decoded = FileClipboardPayload.decode(from: payload) else { return [] }
        return decoded.fileURLs.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    static func displayLabel(for urls: [URL]) -> String {
        guard !urls.isEmpty else { return "File" }
        if urls.count == 1 {
            return urls[0].lastPathComponent
        }
        let names = urls.prefix(4).map(\.lastPathComponent).joined(separator: ", ")
        if urls.count > 4 {
            return "\(names) … (\(urls.count) file)"
        }
        return "\(names) (\(urls.count) file)"
    }

    static func listSubtitle(for urls: [URL]) -> String {
        if urls.count == 1 {
            let parent = urls[0].deletingLastPathComponent().lastPathComponent
            return parent.isEmpty ? "File" : parent
        }
        return "\(urls.count) file"
    }
}

extension ClippingRecord {
    var fileURLs: [URL] {
        guard payloadFormat == .fileURLs else { return [] }
        return FileClipboardSupport.existingURLs(from: payload)
    }

    var isFileCopy: Bool {
        payloadFormat == .fileURLs
    }

    var fileDisplayLabel: String? {
        guard isFileCopy else { return nil }
        let urls = fileURLs
        if !urls.isEmpty {
            return FileClipboardSupport.displayLabel(for: urls)
        }
        if let plainText, !plainText.isEmpty { return plainText }
        return "File"
    }
}
