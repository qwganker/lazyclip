import CryptoKit
import Foundation
import SQLite3

private let sqliteTransientImage = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ImagePage {
    let items: [ImageHistoryItem]
    let hasMore: Bool
}

final class ImageRepository {
    private let databaseManager: DatabaseManager

    init(databasePath: URL) throws {
        databaseManager = try DatabaseManager(databasePath: databasePath)
    }

    func insert(imageData: Data) throws -> ImageHistoryItem {
        let database = databaseManager.database
        let capturedAt = Date()
        let contentHash = SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        INSERT INTO image_history (image_data, content_hash, captured_at, last_recopied_at)
        VALUES (?, ?, ?, NULL)
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        imageData.withUnsafeBytes { ptr in
            sqlite3_bind_blob(statement, 1, ptr.baseAddress, Int32(imageData.count), sqliteTransientImage)
        }
        sqlite3_bind_text(statement, 2, contentHash, -1, sqliteTransientImage)
        sqlite3_bind_int64(statement, 3, Int64(capturedAt.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }

        return ImageHistoryItem(
            id: sqlite3_last_insert_rowid(database),
            imageData: imageData,
            contentHash: contentHash,
            capturedAt: capturedAt,
            lastRecopiedAt: nil,
            isStarred: false
        )
    }

    func fetchLatest() throws -> ImageHistoryItem? {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        SELECT h.id, h.image_data, h.content_hash, h.captured_at, h.last_recopied_at,
               CASE WHEN f.image_history_id IS NOT NULL THEN 1 ELSE 0 END AS is_starred
        FROM image_history h
        LEFT JOIN image_favorite_items f ON f.image_history_id = h.id
        ORDER BY h.captured_at DESC, h.id DESC
        LIMIT 1
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
            return makeItem(from: statement)
        case SQLITE_DONE:
            return nil
        default:
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func fetchPage(limit: Int, offset: Int) throws -> ImagePage {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        SELECT h.id, h.image_data, h.content_hash, h.captured_at, h.last_recopied_at,
               CASE WHEN f.image_history_id IS NOT NULL THEN 1 ELSE 0 END AS is_starred
        FROM image_history h
        LEFT JOIN image_favorite_items f ON f.image_history_id = h.id
        ORDER BY h.captured_at DESC, h.id DESC
        LIMIT ? OFFSET ?
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, Int64(limit + 1))
        sqlite3_bind_int64(statement, 2, Int64(offset))

        var items: [ImageHistoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = makeItem(from: statement) {
                items.append(item)
            }
        }

        let hasMore = items.count > limit
        return ImagePage(items: Array(items.prefix(limit)), hasMore: hasMore)
    }

    func fetchStarredPage(limit: Int, offset: Int) throws -> ImagePage {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        SELECT h.id, h.image_data, h.content_hash, h.captured_at, h.last_recopied_at,
               1 AS is_starred
        FROM image_history h
        INNER JOIN image_favorite_items f ON f.image_history_id = h.id
        ORDER BY f.favorited_at DESC, h.id DESC
        LIMIT ? OFFSET ?
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_int64(statement, 1, Int64(limit + 1))
        sqlite3_bind_int64(statement, 2, Int64(offset))

        var items: [ImageHistoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = makeItem(from: statement) {
                items.append(item)
            }
        }

        let hasMore2 = items.count > limit
        return ImagePage(items: Array(items.prefix(limit)), hasMore: hasMore2)
    }

    func delete(id: Int64) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "DELETE FROM image_history WHERE id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }
        sqlite3_bind_int64(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func addStar(id: Int64, at date: Date = .now) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        INSERT INTO image_favorite_items (image_history_id, favorited_at)
        VALUES (?, ?)
        ON CONFLICT(image_history_id) DO UPDATE SET favorited_at = excluded.favorited_at
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }
        sqlite3_bind_int64(statement, 1, id)
        sqlite3_bind_int64(statement, 2, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func removeStar(id: Int64) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "DELETE FROM image_favorite_items WHERE image_history_id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }
        sqlite3_bind_int64(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func markRecopied(id: Int64, at date: Date = .now) throws {
        let database = databaseManager.database
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "UPDATE image_history SET last_recopied_at = ? WHERE id = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }
        sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, id)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func deleteAll() throws {
        let database = databaseManager.database
        let result = sqlite3_exec(database, "DELETE FROM image_history", nil, nil, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.executionFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    func trimToLimit(_ limit: Int) throws {
        let database = databaseManager.database
        let sql = """
        DELETE FROM image_history
        WHERE id NOT IN (SELECT image_history_id FROM image_favorite_items)
        AND id NOT IN (
            SELECT id FROM image_history
            WHERE id NOT IN (SELECT image_history_id FROM image_favorite_items)
            ORDER BY captured_at DESC, id DESC
            LIMIT ?
        )
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }
        sqlite3_bind_int64(statement, 1, Int64(limit))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    private func makeItem(from statement: OpaquePointer?) -> ImageHistoryItem? {
        guard sqlite3_column_type(statement, 1) != SQLITE_NULL,
              let hashCString = sqlite3_column_text(statement, 2) else {
            return nil
        }
        let id = sqlite3_column_int64(statement, 0)
        let blobPtr = sqlite3_column_blob(statement, 1)
        let blobSize = sqlite3_column_bytes(statement, 1)
        let imageData = blobPtr.map { Data(bytes: $0, count: Int(blobSize)) } ?? Data()
        let capturedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 3)))
        let lastRecopiedAt: Date? = sqlite3_column_type(statement, 4) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))
        let isStarred = sqlite3_column_int(statement, 5) != 0
        return ImageHistoryItem(
            id: id,
            imageData: imageData,
            contentHash: String(cString: hashCString),
            capturedAt: capturedAt,
            lastRecopiedAt: lastRecopiedAt,
            isStarred: isStarred
        )
    }
}
