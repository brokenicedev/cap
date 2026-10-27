import Foundation
import SQLite3

extension ClippingStore {
    func fetchGroups() throws -> [ClipboardGroup] {
        let sql = """
        SELECT id, name, color_hex, sort_order FROM clipboard_groups
        ORDER BY sort_order ASC, name ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ClippingStoreError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        var groups: [ClipboardGroup] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0),
                  let nameC = sqlite3_column_text(stmt, 1),
                  let colorC = sqlite3_column_text(stmt, 2) else { continue }
            let id = UUID(uuidString: String(cString: idC)) ?? UUID()
            groups.append(ClipboardGroup(
                id: id,
                name: String(cString: nameC),
                colorHex: String(cString: colorC),
                sortOrder: Int(sqlite3_column_int(stmt, 3))
            ))
        }
        return groups
    }

    func ensureGroupsSchema() throws {
        try migrateGroupsSchemaIfNeeded()
        guard db != nil else { throw ClippingStoreError.openFailed }
    }

    func createGroup(name: String, colorHex: String) throws -> ClipboardGroup {
        try ensureGroupsSchema()
        let order = (try fetchGroups().map(\.sortOrder).max() ?? -1) + 1
        let group = ClipboardGroup(id: UUID(), name: name, colorHex: colorHex, sortOrder: order)
        try run(
            "INSERT INTO clipboard_groups (id, name, color_hex, sort_order) VALUES (?, ?, ?, ?)"
        ) { stmt in
            sqlite3_bind_text(stmt, 1, group.id.uuidString, -1, sqliteTransient)
            sqlite3_bind_text(stmt, 2, group.name, -1, sqliteTransient)
            sqlite3_bind_text(stmt, 3, group.colorHex, -1, sqliteTransient)
            sqlite3_bind_int(stmt, 4, Int32(group.sortOrder))
        }
        return group
    }

    func updateGroup(_ group: ClipboardGroup) throws {
        try run(
            "UPDATE clipboard_groups SET name = ?, color_hex = ?, sort_order = ? WHERE id = ?"
        ) { stmt in
            sqlite3_bind_text(stmt, 1, group.name, -1, sqliteTransient)
            sqlite3_bind_text(stmt, 2, group.colorHex, -1, sqliteTransient)
            sqlite3_bind_int(stmt, 3, Int32(group.sortOrder))
            sqlite3_bind_text(stmt, 4, group.id.uuidString, -1, sqliteTransient)
        }
    }

    func deleteGroup(id: UUID) throws {
        try run("UPDATE clippings SET group_id = NULL WHERE group_id = ?") { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
        try run("DELETE FROM clipboard_groups WHERE id = ?") { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
    }

    func setGroupOrders(_ groups: [ClipboardGroup]) throws {
        for (index, group) in groups.enumerated() {
            var updated = group
            updated.sortOrder = index
            try updateGroup(updated)
        }
    }

    func migrateGroupsSchemaIfNeeded() throws {
        try run(
            """
            CREATE TABLE IF NOT EXISTS clipboard_groups (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                color_hex TEXT NOT NULL,
                sort_order INTEGER NOT NULL
            );
            """,
            bind: nil
        )
        guard !hasColumn("group_id") else { return }
        try run("ALTER TABLE clippings ADD COLUMN group_id TEXT", bind: nil)
        try migrateLegacyFavoriteSlotsToGroups()
    }

    private func migrateLegacyFavoriteSlotsToGroups() throws {
        guard hasColumn("favorite_slot") else { return }
        for slot in 1...9 {
            let countSQL = "SELECT COUNT(*) FROM clippings WHERE favorite_slot = ?"
            var count = 0
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK, let stmt {
                sqlite3_bind_int(stmt, 1, Int32(slot))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }
            guard count > 0 else { continue }
            let legacyName = Preferences.favoriteListName(slot: slot)
            let color = ClipboardGroup.defaultColor(forOrder: slot - 1)
            let group = try createGroup(name: legacyName, colorHex: color)
            try run("UPDATE clippings SET group_id = ? WHERE favorite_slot = ?") { stmt in
                sqlite3_bind_text(stmt, 1, group.id.uuidString, -1, sqliteTransient)
                sqlite3_bind_int(stmt, 2, Int32(slot))
            }
        }
    }
}
