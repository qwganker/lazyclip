import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SettingsRepository {
    private let databaseManager: DatabaseManager

    init(databasePath: URL) throws {
        databaseManager = try DatabaseManager(databasePath: databasePath)
    }

    func load() throws -> AppSettings {
        let database = databaseManager.database
        let count = try settingsCount(in: database)

        if count == 0 {
            let defaults = AppSettings(isPaused: false, historyLimit: AppConfiguration.defaultHistoryLimit)
            try save(defaults)
            return defaults
        }

        return AppSettings(
            isPaused: try loadBool(forKey: "is_paused", defaultValue: false, in: database),
            historyLimit: try loadInt(forKey: "history_limit", defaultValue: AppConfiguration.defaultHistoryLimit, in: database)
        )
    }

    func save(_ settings: AppSettings) throws {
        let database = databaseManager.database
        try saveValue(settings.isPaused ? "1" : "0", forKey: "is_paused", in: database)
        try saveValue(String(settings.historyLimit), forKey: "history_limit", in: database)
    }

    private func settingsCount(in database: OpaquePointer?) throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "SELECT COUNT(*) FROM app_settings"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func loadBool(forKey key: String, defaultValue: Bool, in database: OpaquePointer?) throws -> Bool {
        guard let value = try loadValue(forKey: key, in: database) else {
            return defaultValue
        }
        return value == "1"
    }

    private func loadInt(forKey key: String, defaultValue: Int, in database: OpaquePointer?) throws -> Int {
        guard let value = try loadValue(forKey: key, in: database), let intValue = Int(value) else {
            return defaultValue
        }
        return intValue
    }

    private func loadValue(forKey key: String, in database: OpaquePointer?) throws -> String? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = "SELECT value FROM app_settings WHERE key = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)

        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
            guard let cString = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: cString)
        case SQLITE_DONE:
            return nil
        default:
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }

    private func saveValue(_ value: String, forKey key: String, in database: OpaquePointer?) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let sql = """
        INSERT INTO app_settings (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET
            value = excluded.value,
            updated_at = excluded.updated_at
        """

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: DatabaseManager.errorMessage(from: database))
        }

        let timestamp = Int64(Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, value, -1, sqliteTransient)
        sqlite3_bind_int64(statement, 3, timestamp)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: DatabaseManager.errorMessage(from: database))
        }
    }
}
