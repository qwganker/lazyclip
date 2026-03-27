# LazyClip Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent favorites to LazyClip so users can star history items, browse them in a dedicated favorites page, and remove them from favorites without deleting the underlying history record.

**Architecture:** Add a separate `favorite_items` SQLite table plus a dedicated `FavoritesRepository` so favorite relationships stay isolated from clipboard history storage. Extend `AppState` to coordinate history and favorites queries, then update the menu bar window UI to switch between history, favorites, and settings while keeping star state synchronized across pages.

**Tech Stack:** Swift, SwiftUI, SQLite3, XCTest, Xcode macOS app target

---

## File Structure

### Models

- `LazyClip/Models/ClipboardHistoryItem.swift`
  Existing persisted history row model.
- `LazyClip/Models/HistoryPage.swift`
  Existing paged history query result.
- `LazyClip/Models/FavoriteHistoryItem.swift`
  New display model for a favorited history row plus `favoritedAt`.

### Persistence

- `LazyClip/Persistence/SchemaMigrator.swift`
  Add the `favorite_items` table and a sort index.
- `LazyClip/Persistence/HistoryRepository.swift`
  Keep history-only responsibilities; do not add favorites logic.
- `LazyClip/Persistence/FavoritesRepository.swift`
  New repository for add/remove/fetch favorite relationships.

### App wiring

- `LazyClip/App/AppContainer.swift`
  Construct `FavoritesRepository` and inject it into `AppState`.
- `LazyClip/State/AppState.swift`
  Add current page state, favorite-id tracking, favorites-page state, and favorite toggle workflows.

### Views

- `LazyClip/Views/HistoryPanelView.swift`
  Add the favorites page and top-level navigation between history, favorites, and settings.
- `LazyClip/Views/HistoryListView.swift`
  Pass favorite state and favorite callbacks into rows.
- `LazyClip/Views/HistoryRowView.swift`
  Add a star button and support hiding the delete action on favorites rows.
- `LazyClip/Views/FavoritesListView.swift`
  New paged list for favorites.
- `LazyClip/Views/FavoritesEmptyStateView.swift`
  New empty state for no favorites.

### Tests

- `LazyClipTests/TestSupport/AppStateHarness.swift`
  Add `FavoritesRepository` wiring for state tests.
- `LazyClipTests/FavoritesRepositoryTests.swift`
  New repository coverage for favorite relationships.
- `LazyClipTests/AppStateTests.swift`
  Add favorites workflows and synchronization coverage.
- `LazyClip.xcodeproj/project.pbxproj`
  Add new source and test files to the targets.

## Build and Test Conventions

- Use `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/FavoritesRepositoryTests` while building repository behavior.
- Use `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests` while building state coordination.
- Use `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'` after view changes.
- Finish with the full suite: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`.
- Commit after each task.

## Task 1: Add Favorites Schema and Repository

**Files:**
- Create: `LazyClip/Models/FavoriteHistoryItem.swift`
- Create: `LazyClip/Persistence/FavoritesRepository.swift`
- Modify: `LazyClip/Persistence/SchemaMigrator.swift`
- Modify: `LazyClip.xcodeproj/project.pbxproj`
- Test: `LazyClipTests/FavoritesRepositoryTests.swift`

- [ ] **Step 1: Write the failing repository tests**

Create `LazyClipTests/FavoritesRepositoryTests.swift`:

```swift
import XCTest
@testable import LazyClip

final class FavoritesRepositoryTests: XCTestCase {
    func testAddFavoriteStoresRelationship() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let item = try historyRepository.insert(content: "first")

        try favoritesRepository.addFavorite(historyItemID: item.id, at: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(
            try favoritesRepository.fetchFavoriteIDs(for: [item.id]),
            Set([item.id])
        )
    }

    func testAddFavoriteUpsertsSameHistoryItem() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let item = try historyRepository.insert(content: "first")

        try favoritesRepository.addFavorite(historyItemID: item.id, at: Date(timeIntervalSince1970: 100))
        try favoritesRepository.addFavorite(historyItemID: item.id, at: Date(timeIntervalSince1970: 200))

        let page = try favoritesRepository.fetchPage(limit: 10, offset: 0)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.historyItem.id, item.id)
        XCTAssertEqual(page.items.first?.favoritedAt, Date(timeIntervalSince1970: 200))
    }

    func testRemoveFavoriteDeletesRelationshipOnly() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let item = try historyRepository.insert(content: "first")
        try favoritesRepository.addFavorite(historyItemID: item.id)

        try favoritesRepository.removeFavorite(historyItemID: item.id)

        XCTAssertTrue(try favoritesRepository.fetchFavoriteIDs(for: [item.id]).isEmpty)
        XCTAssertEqual(try historyRepository.totalCount(), 1)
    }

    func testFetchPageReturnsFavoritesOrderedByMostRecentFavorite() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let first = try historyRepository.insert(content: "first")
        let second = try historyRepository.insert(content: "second")

        try favoritesRepository.addFavorite(historyItemID: first.id, at: Date(timeIntervalSince1970: 100))
        try favoritesRepository.addFavorite(historyItemID: second.id, at: Date(timeIntervalSince1970: 200))

        let page = try favoritesRepository.fetchPage(limit: 10, offset: 0)

        XCTAssertEqual(page.items.map(\.historyItem.content), ["second", "first"])
        XCTAssertEqual(page.items.map(\.favoritedAt), [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 100)
        ])
        XCTAssertFalse(page.hasMore)
    }

    func testFetchFavoriteIDsReturnsOnlyMatchingRelationships() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let first = try historyRepository.insert(content: "first")
        let second = try historyRepository.insert(content: "second")

        try favoritesRepository.addFavorite(historyItemID: second.id)

        XCTAssertEqual(
            try favoritesRepository.fetchFavoriteIDs(for: [first.id, second.id]),
            Set([second.id])
        )
    }

    func testClearAllRemovesAllFavoriteRelationships() throws {
        let db = try TemporaryDatabase()
        let historyRepository = try HistoryRepository(databasePath: db.url)
        let favoritesRepository = try FavoritesRepository(databasePath: db.url)
        let first = try historyRepository.insert(content: "first")
        let second = try historyRepository.insert(content: "second")
        try favoritesRepository.addFavorite(historyItemID: first.id)
        try favoritesRepository.addFavorite(historyItemID: second.id)

        try favoritesRepository.clearAll()

        XCTAssertTrue(try favoritesRepository.fetchFavoriteIDs(for: [first.id, second.id]).isEmpty)
        XCTAssertTrue(try favoritesRepository.fetchPage(limit: 10, offset: 0).items.isEmpty)
        XCTAssertEqual(try historyRepository.totalCount(), 2)
    }
}
```

- [ ] **Step 2: Run the repository tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/FavoritesRepositoryTests`

Expected: FAIL with missing `FavoritesRepository` and `FavoriteHistoryItem` symbols.

- [ ] **Step 3: Add the favorite display model**

Create `LazyClip/Models/FavoriteHistoryItem.swift`:

```swift
import Foundation

struct FavoriteHistoryItem: Identifiable, Equatable {
    let historyItem: ClipboardHistoryItem
    let favoritedAt: Date

    var id: Int64 { historyItem.id }
}
```

- [ ] **Step 4: Extend the schema for favorites**

Update `LazyClip/Persistence/SchemaMigrator.swift` to add the table and index:

```swift
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
```

- [ ] **Step 5: Implement the favorites repository**

Create `LazyClip/Persistence/FavoritesRepository.swift`:

```swift
import Foundation
import SQLite3

private let sqliteTransientFavorites = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
```

- [ ] **Step 6: Add the new files to the Xcode project**

Update `LazyClip.xcodeproj/project.pbxproj` to include:

- `LazyClip/Models/FavoriteHistoryItem.swift` in the app target
- `LazyClip/Persistence/FavoritesRepository.swift` in the app target
- `LazyClipTests/FavoritesRepositoryTests.swift` in the test target

- [ ] **Step 7: Run the repository tests to verify they pass**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/FavoritesRepositoryTests`

Expected: PASS with `Test Suite 'FavoritesRepositoryTests' passed`.

- [ ] **Step 8: Commit**

```bash
git add LazyClip/Models/FavoriteHistoryItem.swift LazyClip/Persistence/FavoritesRepository.swift LazyClip/Persistence/SchemaMigrator.swift LazyClipTests/FavoritesRepositoryTests.swift LazyClip.xcodeproj/project.pbxproj
git commit -m "feat: add favorites persistence"
```

## Task 2: Extend App State for Favorite Synchronization

**Files:**
- Modify: `LazyClip/State/AppState.swift`
- Modify: `LazyClip/App/AppContainer.swift`
- Modify: `LazyClipTests/TestSupport/AppStateHarness.swift`
- Modify: `LazyClipTests/AppStateTests.swift`

- [ ] **Step 1: Write the failing app-state tests**

Append these tests to `LazyClipTests/AppStateTests.swift`:

```swift
    func testLoadInitialDataTracksFavoritedHistoryIDs() throws {
        let harness = try AppStateHarness()
        let first = try harness.historyRepository.insert(content: "first")
        let second = try harness.historyRepository.insert(content: "second")
        try harness.favoritesRepository.addFavorite(historyItemID: first.id)
        let state = harness.makeAppState()

        try state.loadInitialData()

        XCTAssertEqual(state.favoritedItemIDs, Set([first.id]))
        XCTAssertFalse(state.isItemFavorited(second.id))
    }

    func testAddFavoriteMarksHistoryItemAsFavorited() throws {
        let harness = try AppStateHarness()
        let item = try harness.historyRepository.insert(content: "first")
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.addFavorite(historyItemID: item.id)

        XCTAssertTrue(state.isItemFavorited(item.id))
        XCTAssertEqual(try harness.favoritesRepository.fetchFavoriteIDs(for: [item.id]), Set([item.id]))
    }

    func testRemoveFavoriteUnmarksHistoryItemWithoutDeletingHistory() throws {
        let harness = try AppStateHarness()
        let item = try harness.historyRepository.insert(content: "first")
        try harness.favoritesRepository.addFavorite(historyItemID: item.id)
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.removeFavorite(historyItemID: item.id)

        XCTAssertFalse(state.isItemFavorited(item.id))
        XCTAssertTrue(try harness.favoritesRepository.fetchFavoriteIDs(for: [item.id]).isEmpty)
        XCTAssertEqual(try harness.historyRepository.totalCount(), 1)
    }

    func testLoadFavoritesLoadsMostRecentlyFavoritedItems() throws {
        let harness = try AppStateHarness()
        let first = try harness.historyRepository.insert(content: "first")
        let second = try harness.historyRepository.insert(content: "second")
        try harness.favoritesRepository.addFavorite(historyItemID: first.id, at: Date(timeIntervalSince1970: 100))
        try harness.favoritesRepository.addFavorite(historyItemID: second.id, at: Date(timeIntervalSince1970: 200))
        let state = harness.makeAppState()

        try state.loadInitialData()
        try state.loadFavorites()

        XCTAssertEqual(state.favoriteItems.map(\.historyItem.content), ["second", "first"])
    }

    func testRemoveFavoriteFromFavoritesRemovesOnlyFavoritesRow() throws {
        let harness = try AppStateHarness()
        let item = try harness.historyRepository.insert(content: "first")
        try harness.favoritesRepository.addFavorite(historyItemID: item.id)
        let state = harness.makeAppState()

        try state.loadInitialData()
        try state.loadFavorites()
        try state.removeFavorite(historyItemID: item.id)

        XCTAssertTrue(state.favoriteItems.isEmpty)
        XCTAssertFalse(state.isItemFavorited(item.id))
        XCTAssertEqual(try harness.historyRepository.totalCount(), 1)
    }

    func testDeleteHistoryItemAlsoRemovesFavoriteRelationship() throws {
        let harness = try AppStateHarness()
        let item = try harness.historyRepository.insert(content: "first")
        try harness.favoritesRepository.addFavorite(historyItemID: item.id)
        let state = harness.makeAppState()

        try state.loadInitialData()
        try state.loadFavorites()
        try state.delete(item: item)

        XCTAssertTrue(state.favoriteItems.isEmpty)
        XCTAssertFalse(state.isItemFavorited(item.id))
        XCTAssertEqual(try harness.historyRepository.totalCount(), 0)
    }

    func testClearAllAlsoClearsFavoriteState() throws {
        let harness = try AppStateHarness()
        let item = try harness.historyRepository.insert(content: "first")
        try harness.favoritesRepository.addFavorite(historyItemID: item.id)
        let state = harness.makeAppState()

        try state.loadInitialData()
        try state.loadFavorites()
        try state.clearAll()

        XCTAssertTrue(state.items.isEmpty)
        XCTAssertTrue(state.favoriteItems.isEmpty)
        XCTAssertTrue(state.favoritedItemIDs.isEmpty)
    }
```

- [ ] **Step 2: Run the app-state tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests`

Expected: FAIL with missing `favoritesRepository`, `favoriteItems`, `favoritedItemIDs`, `loadFavorites`, `addFavorite`, `removeFavorite`, and `isItemFavorited`.

- [ ] **Step 3: Wire favorites into the test harness and container**

Update `LazyClipTests/TestSupport/AppStateHarness.swift`:

```swift
import Foundation
@testable import LazyClip

struct AppStateHarness {
    let database: TemporaryDatabase
    let settingsRepository: SettingsRepository
    let historyRepository: HistoryRepository
    let favoritesRepository: FavoritesRepository
    let pasteboard: PasteboardSpy
    let clipboardMonitor: ClipboardMonitor

    init() throws {
        database = try TemporaryDatabase()
        settingsRepository = try SettingsRepository(databasePath: database.url)
        historyRepository = try HistoryRepository(databasePath: database.url)
        favoritesRepository = try FavoritesRepository(databasePath: database.url)
        pasteboard = PasteboardSpy()
        clipboardMonitor = ClipboardMonitor(
            pasteboard: pasteboard,
            pollInterval: AppConfiguration.pasteboardPollInterval
        )
    }

    @MainActor
    func makeAppState() -> AppState {
        AppState(
            settingsRepository: settingsRepository,
            historyRepository: historyRepository,
            favoritesRepository: favoritesRepository,
            clipboardMonitor: clipboardMonitor
        )
    }
}
```

Update `LazyClip/App/AppContainer.swift`:

```swift
import Foundation

@MainActor
struct AppContainer {
    let appState: AppState

    init() throws {
        let paths = try ApplicationSupportPaths()
        let settingsRepository = try SettingsRepository(databasePath: paths.databaseURL)
        let historyRepository = try HistoryRepository(databasePath: paths.databaseURL)
        let favoritesRepository = try FavoritesRepository(databasePath: paths.databaseURL)
        let clipboardMonitor = ClipboardMonitor(
            pasteboard: SystemPasteboardClient(),
            pollInterval: AppConfiguration.pasteboardPollInterval
        )

        appState = AppState(
            settingsRepository: settingsRepository,
            historyRepository: historyRepository,
            favoritesRepository: favoritesRepository,
            clipboardMonitor: clipboardMonitor
        )
    }
}
```

- [ ] **Step 4: Add the minimal app-state API and state**

Update the `AppState` stored properties and initializer in `LazyClip/State/AppState.swift`:

```swift
@MainActor
final class AppState: ObservableObject {
    enum Page {
        case history
        case favorites
        case settings
    }

    @Published var settings: AppSettings
    @Published var searchText: String
    @Published var items: [ClipboardHistoryItem]
    @Published var favoriteItems: [FavoriteHistoryItem]
    @Published var currentPage: Page
    @Published var isLoadingMore: Bool
    @Published var isLoadingMoreFavorites: Bool
    @Published var storageErrorMessage: String?

    private let settingsRepository: SettingsRepository
    private let historyRepository: HistoryRepository
    private let favoritesRepository: FavoritesRepository
    private let clipboardMonitor: ClipboardMonitor
    private(set) var favoritedItemIDs: Set<Int64>
    private var currentOffset: Int
    private var hasMorePages: Bool
    private var favoriteOffset: Int
    private var favoriteHasMorePages: Bool

    init(
        settingsRepository: SettingsRepository,
        historyRepository: HistoryRepository,
        favoritesRepository: FavoritesRepository,
        clipboardMonitor: ClipboardMonitor
    ) {
        self.settingsRepository = settingsRepository
        self.historyRepository = historyRepository
        self.favoritesRepository = favoritesRepository
        self.clipboardMonitor = clipboardMonitor
        settings = AppSettings(isPaused: false, historyLimit: AppConfiguration.defaultHistoryLimit)
        searchText = ""
        items = []
        favoriteItems = []
        currentPage = .history
        isLoadingMore = false
        isLoadingMoreFavorites = false
        storageErrorMessage = nil
        favoritedItemIDs = []
        currentOffset = 0
        hasMorePages = false
        favoriteOffset = 0
        favoriteHasMorePages = false
    }
```

- [ ] **Step 5: Implement favorites loading and synchronization**

Add these methods to `LazyClip/State/AppState.swift`:

```swift
    func isItemFavorited(_ historyItemID: Int64) -> Bool {
        favoritedItemIDs.contains(historyItemID)
    }

    func loadFavorites() throws {
        let page = try favoritesRepository.fetchPage(limit: AppConfiguration.historyPageSize, offset: 0)
        favoriteItems = page.items
        favoriteOffset = page.items.count
        favoriteHasMorePages = page.hasMore
        storageErrorMessage = nil
    }

    func addFavorite(historyItemID: Int64) throws {
        try favoritesRepository.addFavorite(historyItemID: historyItemID)
        favoritedItemIDs.insert(historyItemID)
        try refreshLoadedFavoritesIfNeeded()
        storageErrorMessage = nil
    }

    func removeFavorite(historyItemID: Int64) throws {
        try favoritesRepository.removeFavorite(historyItemID: historyItemID)
        favoritedItemIDs.remove(historyItemID)
        favoriteItems.removeAll { $0.historyItem.id == historyItemID }
        if currentPage == .favorites {
            try refreshLoadedFavoritesIfNeeded()
        }
        storageErrorMessage = nil
    }

    private func refreshFavoriteIDs() throws {
        favoritedItemIDs = try favoritesRepository.fetchFavoriteIDs(for: items.map(\.id))
    }

    private func refreshLoadedFavoritesIfNeeded() throws {
        guard favoriteItems.isEmpty == false || currentPage == .favorites else {
            return
        }
        try loadFavorites()
    }
```

- [ ] **Step 6: Connect the existing history actions to favorites cleanup**

Update these methods in `LazyClip/State/AppState.swift`:

```swift
    func loadInitialData() throws {
        settings = try settingsRepository.load()
        try reloadFirstPage()
        try loadFavorites()
    }

    func delete(item: ClipboardHistoryItem) throws {
        try historyRepository.delete(id: item.id)
        try favoritesRepository.removeFavorite(historyItemID: item.id)
        try reloadFirstPage()
        favoriteItems.removeAll { $0.historyItem.id == item.id }
        favoritedItemIDs.remove(item.id)
    }

    func clearAll() throws {
        try historyRepository.clearAll()
        try favoritesRepository.clearAll()
        try reloadFirstPage()
        favoriteItems = []
        favoritedItemIDs = []
    }

    private func reloadFirstPage() throws {
        let page = try historyRepository.fetchPage(
            searchText: normalizedSearchText,
            limit: AppConfiguration.historyPageSize,
            offset: 0
        )
        items = page.items
        currentOffset = page.items.count
        hasMorePages = page.hasMore
        isLoadingMore = false
        try refreshFavoriteIDs()
        storageErrorMessage = nil
    }
```

- [ ] **Step 7: Run the app-state tests to verify they pass**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests`

Expected: PASS with `Test Suite 'AppStateTests' passed`.

- [ ] **Step 8: Commit**

```bash
git add LazyClip/App/AppContainer.swift LazyClip/State/AppState.swift LazyClipTests/TestSupport/AppStateHarness.swift LazyClipTests/AppStateTests.swift
git commit -m "feat: add favorites app state"
```

## Task 3: Build the Favorites UI and Favorite Actions

**Files:**
- Create: `LazyClip/Views/FavoritesListView.swift`
- Create: `LazyClip/Views/FavoritesEmptyStateView.swift`
- Modify: `LazyClip/Views/HistoryPanelView.swift`
- Modify: `LazyClip/Views/HistoryListView.swift`
- Modify: `LazyClip/Views/HistoryRowView.swift`
- Modify: `LazyClip.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the reusable favorites empty state**

Create `LazyClip/Views/FavoritesEmptyStateView.swift`:

```swift
import SwiftUI

struct FavoritesEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "star",
            description: Text("Star items from history to keep them here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Add the favorites list view**

Create `LazyClip/Views/FavoritesListView.swift`:

```swift
import SwiftUI

struct FavoritesListView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.favoriteItems) { item in
                HistoryRowView(
                    item: item.historyItem,
                    isFavorited: true,
                    showsDeleteButton: false,
                    onSelect: {
                        do {
                            try appState.select(item: item.historyItem)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onToggleFavorite: {
                        do {
                            try appState.removeFavorite(historyItemID: item.historyItem.id)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onDelete: nil
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if appState.isLoadingMoreFavorites {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, 2, for: .scrollContent)
    }
}
```

- [ ] **Step 3: Extend the history row for favorite toggling**

Update `LazyClip/Views/HistoryRowView.swift`:

```swift
import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardHistoryItem
    let isFavorited: Bool
    let showsDeleteButton: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: handleSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorited ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .help(isFavorited ? "Remove favorite" : "Add favorite")

            if showsDeleteButton, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete item")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .onHover { hovered in
            isHovered = hovered
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
    }

    private func handleSelect() {
        isPressed = true
        onSelect()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            isPressed = false
        }
    }
}
```

- [ ] **Step 4: Pass favorite state into the history list**

Update `LazyClip/Views/HistoryListView.swift`:

```swift
import SwiftUI

struct HistoryListView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.items) { item in
                HistoryRowView(
                    item: item,
                    isFavorited: appState.isItemFavorited(item.id),
                    showsDeleteButton: true,
                    onSelect: {
                        do {
                            try appState.select(item: item)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onToggleFavorite: {
                        do {
                            if appState.isItemFavorited(item.id) {
                                try appState.removeFavorite(historyItemID: item.id)
                            } else {
                                try appState.addFavorite(historyItemID: item.id)
                            }
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onDelete: {
                        do {
                            try appState.delete(item: item)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onAppear {
                    do {
                        try appState.loadNextPageIfNeeded(currentItem: item)
                    } catch {
                        appState.storageErrorMessage = error.localizedDescription
                    }
                }
            }

            if appState.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, 2, for: .scrollContent)
    }
}
```

- [ ] **Step 5: Add the favorites page and page navigation**

Update `LazyClip/Views/HistoryPanelView.swift`:

```swift
import AppKit
import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.currentPage {
            case .history:
                historyPage
            case .favorites:
                favoritesPage
            case .settings:
                settingsPage
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var historyPage: some View {
        VStack(spacing: 0) {
            historyHeader
            Divider()

            if appState.settings.isPaused {
                PausedBannerView()
            }

            VStack(spacing: 6) {
                TextField("Search clipboard history", text: searchBinding)
                    .textFieldStyle(.roundedBorder)

                if let storageErrorMessage = appState.storageErrorMessage {
                    Text(storageErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(Color(nsColor: .windowBackgroundColor))

            if appState.items.isEmpty {
                ContentUnavailableView(
                    "No Clipboard History",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copied text will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HistoryListView(appState: appState)
            }
        }
    }

    private var favoritesPage: some View {
        VStack(spacing: 0) {
            favoritesHeader
            Divider()

            if let storageErrorMessage = appState.storageErrorMessage {
                Text(storageErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }

            if appState.favoriteItems.isEmpty {
                FavoritesEmptyStateView()
            } else {
                FavoritesListView(appState: appState)
            }
        }
        .task {
            if appState.favoriteItems.isEmpty {
                try? appState.loadFavorites()
            }
        }
    }

    private var settingsPage: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            SettingsView(appState: appState)
        }
    }

    private var historyHeader: some View {
        HStack(spacing: 12) {
            Label("LazyClip", systemImage: "paperclip")
                .font(.headline)

            Spacer()

            Button("Favorites") {
                appState.currentPage = .favorites
            }
            .buttonStyle(.plain)

            Button {
                appState.currentPage = .settings
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var favoritesHeader: some View {
        HStack(spacing: 12) {
            Button {
                appState.currentPage = .history
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back to History")

            Text("Favorites")
                .font(.headline)

            Spacer()

            Button {
                appState.currentPage = .settings
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Button {
                appState.currentPage = .history
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back")

            Text("Settings")
                .font(.headline)

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { appState.searchText },
            set: { newValue in
                do {
                    try appState.updateSearchText(newValue)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }
}
```

- [ ] **Step 6: Add the new view files to the Xcode project**

Update `LazyClip.xcodeproj/project.pbxproj` to include:

- `LazyClip/Views/FavoritesListView.swift`
- `LazyClip/Views/FavoritesEmptyStateView.swift`

in the app target.

- [ ] **Step 7: Run a build to verify the UI compiles**

Run: `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add LazyClip/Views/FavoritesListView.swift LazyClip/Views/FavoritesEmptyStateView.swift LazyClip/Views/HistoryPanelView.swift LazyClip/Views/HistoryListView.swift LazyClip/Views/HistoryRowView.swift LazyClip.xcodeproj/project.pbxproj
git commit -m "feat: add favorites interface"
```

## Task 4: Verify End-to-End Favorites Behavior

**Files:**
- Modify: `LazyClip/State/AppState.swift`
- Modify: `LazyClipTests/AppStateTests.swift`

- [ ] **Step 1: Add pagination coverage for favorites if needed**

Append this test to `LazyClipTests/AppStateTests.swift` if `loadFavorites()` and favorites refresh logic do not already cover ordering and reload behavior strongly enough:

```swift
    func testAddFavoriteReloadsFavoritesInMostRecentFirstOrder() throws {
        let harness = try AppStateHarness()
        let first = try harness.historyRepository.insert(content: "first")
        let second = try harness.historyRepository.insert(content: "second")
        let state = harness.makeAppState()

        try state.loadInitialData()
        try state.addFavorite(historyItemID: first.id)
        try state.addFavorite(historyItemID: second.id)

        XCTAssertEqual(state.favoriteItems.map(\.historyItem.content), ["second", "first"])
    }
```

- [ ] **Step 2: Run the targeted app-state tests**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests`

Expected: PASS with `Test Suite 'AppStateTests' passed`.

- [ ] **Step 3: Run the full test suite**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add LazyClip/State/AppState.swift LazyClipTests/AppStateTests.swift
git commit -m "test: verify favorites workflows"
```

## Task 5: Update Project Instructions

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the architecture snapshot and feature list**

Update `CLAUDE.md` so it mentions:

```md
- favorites stored as a separate SQLite relationship table
- a dedicated `FavoritesRepository`
- menu bar history UI plus favorites page and in-panel settings UI
```

- [ ] **Step 2: Run a diff review for the documentation change**

Run: `git diff -- CLAUDE.md`

Expected: the diff mentions favorites behavior and does not reintroduce stale worktree instructions.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document favorites architecture"
```

## Self-Review

### Spec coverage

- Separate `favorite_items` table: Task 1
- Dedicated `FavoritesRepository`: Task 1
- Favorites page in the existing menu bar window: Task 3
- History rows show star + delete: Task 3
- Favorites rows show star only: Task 3
- Removing a favorite keeps history intact: Tasks 1, 2, and 3
- Synchronization between history and favorites: Task 2
- Tests for repository and state behavior: Tasks 1, 2, and 4
- Documentation update to keep repo guidance current: Task 5

### Placeholder scan

- No `TBD`, `TODO`, or “similar to Task N” placeholders remain.
- Every task includes exact file paths, concrete code, and executable commands.

### Type consistency

- `FavoriteHistoryItem`, `FavoritesRepository`, `favoritedItemIDs`, `favoriteItems`, `addFavorite`, `removeFavorite`, `loadFavorites`, and `isItemFavorited` are named consistently across tasks.
- `HistoryRepository` remains history-only throughout the plan.
