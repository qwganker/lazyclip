import Foundation
import SQLite3

final class FavoritesRepository {
    private let databaseManager: DatabaseManager

    init(databasePath: URL) throws {
        databaseManager = try DatabaseManager(databasePath: databasePath)
    }

    func addFavorite(historyItemID: Int64, at: Date = .now) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        INSERT INTO favorite_items (history_item_id, favorited_at)
        VALUES (?, ?)
        ON CONFLICT(history_item_id) DO UPDATE SET
            favorited_at = excluded.favorited_at
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, historyItemID)
        sqlite3_bind_int64(statement, 2, Int64(at.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func removeFavorite(historyItemID: Int64) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "DELETE FROM favorite_items WHERE history_item_id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, historyItemID)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func fetchFavoriteIDs(for historyItemIDs: [Int64]) throws -> Set<Int64> {
        guard historyItemIDs.isEmpty == false else {
            return []
        }

        let placeholders = Array(repeating: "?", count: historyItemIDs.count).joined(separator: ", ")
        let sql = "SELECT history_item_id FROM favorite_items WHERE history_item_id IN (\(placeholders))"
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        for (index, id) in historyItemIDs.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), id)
        }

        var ids = Set<Int64>()
        while sqlite3_step(statement) == SQLITE_ROW {
            ids.insert(sqlite3_column_int64(statement, 0))
        }

        return ids
    }

    func fetchPage(limit: Int, offset: Int) throws -> (items: [FavoriteHistoryItem], hasMore: Bool) {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        SELECT
            h.id,
            h.content,
            h.content_hash,
            h.captured_at,
            h.last_recopied_at,
            f.favorited_at
        FROM favorite_items f
        JOIN clipboard_history h ON h.id = f.history_item_id
        ORDER BY f.favorited_at DESC, h.id DESC
        LIMIT ? OFFSET ?
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, Int64(limit + 1))
        sqlite3_bind_int64(statement, 2, Int64(offset))

        var items: [FavoriteHistoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let historyItem = try makeHistoryItem(from: statement)
            let favoritedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 5)))
            items.append(FavoriteHistoryItem(historyItem: historyItem, favoritedAt: favoritedAt))
        }

        let hasMore = items.count > limit
        if hasMore {
            items.removeLast()
        }

        return (items, hasMore)
    }

    func clearAll() throws {
        let database = databaseManager.database
        let result = sqlite3_exec(database, "DELETE FROM favorite_items", nil, nil, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.executionFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    private func makeHistoryItem(from statement: OpaquePointer?) throws -> ClipboardHistoryItem {
        guard
            let contentCString = sqlite3_column_text(statement, 1),
            let hashCString = sqlite3_column_text(statement, 2)
        else {
            throw DatabaseError.stepFailed(message: "Failed to read favorite history row")
        }

        let id = sqlite3_column_int64(statement, 0)
        let capturedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 3)))
        let lastRecopiedAt: Date?
        if sqlite3_column_type(statement, 4) == SQLITE_NULL {
            lastRecopiedAt = nil
        } else {
            lastRecopiedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))
        }

        return ClipboardHistoryItem(
            id: id,
            content: String(cString: contentCString),
            contentHash: String(cString: hashCString),
            capturedAt: capturedAt,
            lastRecopiedAt: lastRecopiedAt
        )
    }
}
