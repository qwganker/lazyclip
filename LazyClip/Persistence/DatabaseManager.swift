import Foundation
import SQLite3

enum DatabaseError: Error, LocalizedError {
    case openFailed(path: String, code: Int32, message: String)
    case executionFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)

    var errorDescription: String? {
        switch self {
        case let .openFailed(path, code, message):
            return "Failed to open SQLite database at \(path) (code \(code)): \(message)"
        case let .executionFailed(message), let .prepareFailed(message), let .stepFailed(message):
            return message
        }
    }
}

final class DatabaseManager {
    let database: OpaquePointer?

    init(databasePath: URL) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open(databasePath.path, &handle)

        guard result == SQLITE_OK, let handle else {
            let message = DatabaseManager.errorMessage(from: handle)
            sqlite3_close(handle)
            throw DatabaseError.openFailed(path: databasePath.path, code: result, message: message)
        }

        database = handle
        try SchemaMigrator.migrate(database: handle)
    }

    deinit {
        sqlite3_close(database)
    }

    static func errorMessage(from database: OpaquePointer?) -> String {
        guard let database, let cString = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: cString)
    }
}
