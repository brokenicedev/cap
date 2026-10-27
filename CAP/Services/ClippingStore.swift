import CryptoKit
import Foundation
import SQLite3
import UniformTypeIdentifiers

enum ClippingStoreError: Error {
    case openFailed
    case prepareFailed
    case executionFailed
}

final class ClippingStore {
    var db: OpaquePointer?

    init() {
        let url = Self.databaseURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            db = nil
            return
        }
        do {
            try createSchemaIfNeeded()
        } catch {
            NSLog("\(AppIdentity.name): database schema error: \(error)")
        }
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    func insert(snapshot: PasteboardSnapshot) throws -> ClippingRecord {
        let record = Self.record(from: snapshot)
        let sql = """
        INSERT INTO clippings (id, created_at, title, plain_text, payload, payload_format, source_bundle_id, is_starred, group_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, NULL)
        ON CONFLICT(id) DO UPDATE SET
            created_at = excluded.created_at,
            title = excluded.title,
            plain_text = excluded.plain_text,
            payload = excluded.payload,
            payload_format = excluded.payload_format,
            source_bundle_id = excluded.source_bundle_id
        """
        try run(sql) { stmt in
            sqlite3_bind_text(stmt, 1, record.id.uuidString, -1, sqliteTransient)
            sqlite3_bind_double(stmt, 2, record.createdAt.timeIntervalSince1970)
            self.bindOptionalText(stmt, 3, record.title)
            self.bindOptionalText(stmt, 4, record.plainText)
            sqlite3_bind_blob(stmt, 5, (record.payload as NSData).bytes, Int32(record.payload.count), nil)
            sqlite3_bind_text(stmt, 6, record.payloadFormat.rawValue, -1, sqliteTransient)
            self.bindOptionalText(stmt, 7, record.sourceBundleID)
        }
        return record
    }

    func fetchRecent(limit: Int) throws -> [ClippingRecord] {
        let sql = """
        SELECT id, created_at, title, plain_text, payload, payload_format, source_bundle_id, is_starred, group_id
        FROM clippings
        ORDER BY is_starred DESC, created_at DESC
        LIMIT ?
        """
        return try query(sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
        }
    }

    func fetch(scope: HistoryScope, limit: Int) throws -> [ClippingRecord] {
        switch scope {
        case .general:
            let sql = """
            SELECT id, created_at, title, plain_text, payload, payload_format, source_bundle_id, is_starred, group_id
            FROM clippings
            WHERE group_id IS NULL
            ORDER BY created_at DESC
            LIMIT ?
            """
            return try query(sql) { stmt in
                sqlite3_bind_int(stmt, 1, Int32(limit))
            }
        case .group(let groupId):
            let sql = """
            SELECT id, created_at, title, plain_text, payload, payload_format, source_bundle_id, is_starred, group_id
            FROM clippings
            WHERE group_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            """
            return try query(sql) { stmt in
                sqlite3_bind_text(stmt, 1, groupId.uuidString, -1, sqliteTransient)
                sqlite3_bind_int(stmt, 2, Int32(limit))
            }
        }
    }

    func setGroupId(id: UUID, groupId: UUID?) throws -> ClippingRecord {
        let sql = "UPDATE clippings SET group_id = ? WHERE id = ?"
        try run(sql) { stmt in
            if let groupId {
                sqlite3_bind_text(stmt, 1, groupId.uuidString, -1, sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_text(stmt, 2, id.uuidString, -1, sqliteTransient)
        }
        guard let row = try fetchOne(id: id) else { throw ClippingStoreError.executionFailed }
        return row
    }

    func clearScope(_ scope: HistoryScope) throws {
        switch scope {
        case .general:
            try run("DELETE FROM clippings WHERE group_id IS NULL", bind: nil)
        case .group(let groupId):
            try run("DELETE FROM clippings WHERE group_id = ?") { stmt in
                sqlite3_bind_text(stmt, 1, groupId.uuidString, -1, sqliteTransient)
            }
        }
    }

    func setStarred(id: UUID, starred: Bool) throws -> ClippingRecord {
        let sql = "UPDATE clippings SET is_starred = ? WHERE id = ?"
        try run(sql) { stmt in
            sqlite3_bind_int(stmt, 1, starred ? 1 : 0)
            sqlite3_bind_text(stmt, 2, id.uuidString, -1, sqliteTransient)
        }
        guard let row = try fetchOne(id: id) else {
            throw ClippingStoreError.executionFailed
        }
        return row
    }

    func delete(id: UUID) throws {
        try run("DELETE FROM clippings WHERE id = ?") { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
    }

    func deleteAll() throws {
        try run("DELETE FROM clippings", bind: nil)
    }

    func trimToMaxCount(_ max: Int) throws {
        let sql = """
        DELETE FROM clippings WHERE id NOT IN (
            SELECT id FROM clippings ORDER BY created_at DESC LIMIT ?
        )
        """
        try run(sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(max))
        }
    }

    // MARK: - Private

    private func createSchemaIfNeeded() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS clippings (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            title TEXT,
            plain_text TEXT,
            payload BLOB NOT NULL,
            payload_format TEXT NOT NULL,
            source_bundle_id TEXT,
            is_starred INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_clippings_created ON clippings(created_at DESC);
        """
        try run(sql, bind: nil)
        try migrateFavoriteSlotIfNeeded()
        try migrateGroupsSchemaIfNeeded()
    }

    private func migrateFavoriteSlotIfNeeded() throws {
        guard !hasColumn("favorite_slot") else { return }
        try run("ALTER TABLE clippings ADD COLUMN favorite_slot INTEGER", bind: nil)
    }

    func hasColumn(_ name: String) -> Bool {
        guard let stmt = prepareUnchecked("PRAGMA table_info(clippings)") else { return false }
        defer { sqlite3_finalize(stmt) }
        let target = name.lowercased()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 1) {
                if String(cString: c).lowercased() == target { return true }
            }
        }
        return false
    }

    private func prepareUnchecked(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    private func fetchOne(id: UUID) throws -> ClippingRecord? {
        let rows = try query(
            "SELECT id, created_at, title, plain_text, payload, payload_format, source_bundle_id, is_starred, group_id FROM clippings WHERE id = ?"
        ) { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
        return rows.first
    }

    private func query(_ sql: String, bind: ((OpaquePointer?) -> Void)?) throws -> [ClippingRecord] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ClippingStoreError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        var results: [ClippingRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let row = readRow(stmt) { results.append(row) }
        }
        return results
    }

    func run(_ sql: String, bind: ((OpaquePointer?) -> Void)?) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ClippingStoreError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ClippingStoreError.executionFailed
        }
    }

    private func readRow(_ stmt: OpaquePointer?) -> ClippingRecord? {
        guard let idCString = sqlite3_column_text(stmt, 0) else { return nil }
        let id = UUID(uuidString: String(cString: idCString)) ?? UUID()
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        let title = optionalString(stmt, 2)
        let plain = optionalString(stmt, 3)
        let payloadLen = sqlite3_column_bytes(stmt, 4)
        guard let payloadPtr = sqlite3_column_blob(stmt, 4), payloadLen > 0 else { return nil }
        let payload = Data(bytes: payloadPtr, count: Int(payloadLen))
        let formatRaw = String(cString: sqlite3_column_text(stmt, 5))
        let format = PayloadFormat(rawValue: formatRaw) ?? .plainText
        let bundle = optionalString(stmt, 6)
        let starred = sqlite3_column_int(stmt, 7) != 0
        let groupId: UUID? = {
            if sqlite3_column_type(stmt, 8) == SQLITE_NULL { return nil }
            guard let c = sqlite3_column_text(stmt, 8) else { return nil }
            return UUID(uuidString: String(cString: c))
        }()
        return ClippingRecord(
            id: id,
            createdAt: createdAt,
            title: title,
            plainText: plain,
            payload: payload,
            payloadFormat: format,
            sourceBundleID: bundle,
            isStarred: starred,
            groupId: groupId
        )
    }

    private func optionalString(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static func databaseURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let capDir = appSupport.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
        let dbURL = capDir.appendingPathComponent("history.sqlite3", isDirectory: false)
        migrateLegacyDatabaseIfNeeded(capDir: capDir, dbURL: dbURL, appSupport: appSupport)
        return dbURL
    }

    private static func migrateLegacyDatabaseIfNeeded(capDir: URL, dbURL: URL, appSupport: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: dbURL.path) else { return }

        let legacyDB = appSupport
            .appendingPathComponent(AppIdentity.legacySupportDirectoryName, isDirectory: true)
            .appendingPathComponent("history.sqlite3", isDirectory: false)
        guard fm.fileExists(atPath: legacyDB.path) else { return }

        do {
            try fm.createDirectory(at: capDir, withIntermediateDirectories: true)
            try fm.moveItem(at: legacyDB, to: dbURL)
            let legacyDir = legacyDB.deletingLastPathComponent()
            if let entries = try? fm.contentsOfDirectory(atPath: legacyDir.path), entries.isEmpty {
                try? fm.removeItem(at: legacyDir)
            }
        } catch {
            NSLog("\(AppIdentity.name): legacy database migration failed: \(error)")
        }
    }

    private static func record(from snapshot: PasteboardSnapshot) -> ClippingRecord {
        let id = contentID(for: snapshot)
        let (payload, format) = primaryPayload(from: snapshot)
        return ClippingRecord(
            id: id,
            createdAt: Date(),
            title: snapshot.suggestedTitle,
            plainText: snapshot.plainText,
            payload: payload,
            payloadFormat: format,
            sourceBundleID: snapshot.sourceBundleID,
            isStarred: false,
            groupId: nil
        )
    }

    private static func contentID(for snapshot: PasteboardSnapshot) -> UUID {
        var hasher = SHA256()
        if let t = snapshot.plainText { hasher.update(data: Data(t.utf8)) }
        if let r = snapshot.rtfData { hasher.update(data: r) }
        if let h = snapshot.htmlData { hasher.update(data: h) }
        if let i = snapshot.imageData { hasher.update(data: i) }
        if let urls = snapshot.fileURLs {
            for url in urls {
                hasher.update(data: Data(url.path.utf8))
            }
        }
        let digest = Array(hasher.finalize())
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func primaryPayload(from snapshot: PasteboardSnapshot) -> (Data, PayloadFormat) {
        if let urls = snapshot.fileURLs, !urls.isEmpty {
            return (FileClipboardPayload.encode(urls: urls), .fileURLs)
        }
        if let image = snapshot.imageData {
            if snapshot.imageUTI == UTType.tiff.identifier {
                return (image, .tiff)
            }
            return (image, .png)
        }
        if let rtf = snapshot.rtfData { return (rtf, .rtf) }
        if let html = snapshot.htmlData { return (html, .html) }
        let text = snapshot.plainText ?? ""
        return (Data(text.utf8), .plainText)
    }
}

let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
