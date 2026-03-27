import CryptoKit
import Foundation
import SQLite3

private let sqliteTransientHistory = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class HistoryRepository {
    private let databaseManager: DatabaseManager

    init(databasePath: URL) throws {
        databaseManager = try DatabaseManager(databasePath: databasePath)
    }

    func insert(content: String) throws -> ClipboardHistoryItem {
        let database = databaseManager.database
        let capturedAt = Date()
        let contentHash = SHA256.hash(data: Data(content.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        INSERT INTO clipboard_history (content, content_hash, captured_at, last_recopied_at)
        VALUES (?, ?, ?, NULL)
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_text(statement, 1, content, -1, sqliteTransientHistory)
        sqlite3_bind_text(statement, 2, contentHash, -1, sqliteTransientHistory)
        sqlite3_bind_int64(statement, 3, Int64(capturedAt.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }

        return ClipboardHistoryItem(
            id: sqlite3_last_insert_rowid(database),
            content: content,
            contentHash: contentHash,
            capturedAt: capturedAt,
            lastRecopiedAt: nil
        )
    }

    func fetchLatest() throws -> ClipboardHistoryItem? {
        try fetchSingle(
            sql: """
            SELECT id, content, content_hash, captured_at, last_recopied_at
            FROM clipboard_history
            ORDER BY captured_at DESC, id DESC
            LIMIT 1
            """
        )
    }

    func fetchPage(searchText: String?, limit: Int, offset: Int) throws -> HistoryPage {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let hasSearchText = !(searchText?.isEmpty ?? true)
        let sql: String
        if hasSearchText {
            sql = """
            SELECT id, content, content_hash, captured_at, last_recopied_at
            FROM clipboard_history
            WHERE content LIKE ?
            ORDER BY captured_at DESC, id DESC
            LIMIT ? OFFSET ?
            """
        } else {
            sql = """
            SELECT id, content, content_hash, captured_at, last_recopied_at
            FROM clipboard_history
            ORDER BY captured_at DESC, id DESC
            LIMIT ? OFFSET ?
            """
        }

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        var bindIndex: Int32 = 1
        if let searchText, !searchText.isEmpty {
            sqlite3_bind_text(statement, bindIndex, "%\(searchText)%", -1, sqliteTransientHistory)
            bindIndex += 1
        }
        sqlite3_bind_int64(statement, bindIndex, Int64(limit + 1))
        sqlite3_bind_int64(statement, bindIndex + 1, Int64(offset))

        var items: [ClipboardHistoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(try makeItem(from: statement))
        }

        let hasMore = items.count > limit
        if hasMore {
            items.removeLast()
        }

        return HistoryPage(items: items, offset: offset, limit: limit, hasMore: hasMore)
    }

    func trimToLimit(_ limit: Int) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        DELETE FROM clipboard_history
        WHERE id IN (
            SELECT id
            FROM clipboard_history
            ORDER BY captured_at DESC, id DESC
            LIMIT -1 OFFSET ?
        )
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, Int64(limit))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func markRecopied(id: Int64, at: Date = .now) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "UPDATE clipboard_history SET last_recopied_at = ? WHERE id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, Int64(at.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, id)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func delete(id: Int64) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "DELETE FROM clipboard_history WHERE id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, id)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func clearAll() throws {
        let database = databaseManager.database
        let sql = "DELETE FROM clipboard_history"
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.executionFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func totalCount() throws -> Int {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "SELECT COUNT(*) FROM clipboard_history"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func fetchSingle(sql: String) throws -> ClipboardHistoryItem? {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
            return try makeItem(from: statement)
        case SQLITE_DONE:
            return nil
        default:
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    private func makeItem(from statement: OpaquePointer?) throws -> ClipboardHistoryItem {
        guard
            let contentCString = sqlite3_column_text(statement, 1),
            let hashCString = sqlite3_column_text(statement, 2)
        else {
            throw DatabaseError.stepFailed(message: "Failed to read clipboard history row")
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
