import Foundation
import SQLite3

enum SchemaMigrator {
    static func migrate(database: OpaquePointer?) throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS clipboard_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                captured_at INTEGER NOT NULL,
                last_recopied_at INTEGER
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_clipboard_history_captured_at
            ON clipboard_history (captured_at DESC, id DESC);
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_clipboard_history_content_hash
            ON clipboard_history (content_hash);
            """,
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS favorite_items (
                history_item_id INTEGER PRIMARY KEY,
                favorited_at INTEGER NOT NULL
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_favorite_items_favorited_at
            ON favorite_items (favorited_at DESC, history_item_id DESC);
            """
        ]

        for statement in statements {
            let result = sqlite3_exec(database, statement, nil, nil, nil)
            guard result == SQLITE_OK else {
                throw DatabaseError.executionFailed(message: DatabaseManager.errorMessage(from: database))
            }
        }
    }
}
