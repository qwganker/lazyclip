# macOS Clipboard History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS 14+ menu bar clipboard history app in SwiftUI that records plain text into SQLite, supports search and paging, and lets users re-copy, delete, pause recording, clear history, and configure the retention limit.

**Architecture:** The app is a SwiftUI `MenuBarExtra` with a separate SwiftUI `Settings` scene. Clipboard access is isolated behind a small `NSPasteboard` adapter, SQLite persistence is wrapped in focused repositories, and a single `AppState` coordinates startup, pagination, search, and re-copy behavior.

**Tech Stack:** Swift, SwiftUI, AppKit (`NSPasteboard` only), SQLite3, CryptoKit, XCTest, Xcode macOS app target

---

## File Structure

### App shell

- `LazyClip.xcodeproj/project.pbxproj`
  Project definition, app target, unit test target, linked `libsqlite3.tbd`, shared scheme.
- `LazyClip/Info.plist`
  Set `LSUIElement=1` so the app lives in the menu bar without a Dock icon.
- `LazyClip/App/LazyClipApp.swift`
  SwiftUI entry point, `MenuBarExtra`, `Settings` scene, injects shared state.
- `LazyClip/App/AppConfiguration.swift`
  Central constants such as default history limit, page size, and pasteboard poll interval.
- `LazyClip/App/AppContainer.swift`
  Creates the live repositories, clipboard monitor, and `AppState`.

### Models

- `LazyClip/Models/AppSettings.swift`
  Pause state and history limit.
- `LazyClip/Models/ClipboardHistoryItem.swift`
  A persisted history row for display and reuse.
- `LazyClip/Models/HistoryPage.swift`
  One page of query results plus enough metadata to keep loading more.

### Persistence

- `LazyClip/Persistence/ApplicationSupportPaths.swift`
  Builds the database file URL in Application Support.
- `LazyClip/Persistence/DatabaseManager.swift`
  Opens SQLite and exposes a safe connection wrapper.
- `LazyClip/Persistence/SchemaMigrator.swift`
  Creates `clipboard_history` and `app_settings`.
- `LazyClip/Persistence/SettingsRepository.swift`
  Loads and saves pause state and history limit.
- `LazyClip/Persistence/HistoryRepository.swift`
  Inserts, queries, deletes, clears, updates `last_recopied_at`, and trims to the configured limit.

### Clipboard

- `LazyClip/Clipboard/PasteboardClient.swift`
  Protocol for reading and writing plain text clipboard values.
- `LazyClip/Clipboard/SystemPasteboardClient.swift`
  `NSPasteboard` implementation.
- `LazyClip/Clipboard/ClipboardMonitor.swift`
  Polls `changeCount`, ignores self-writes, and publishes accepted strings.

### State

- `LazyClip/State/AppState.swift`
  Startup flow, search state, pagination, delete/clear actions, pause handling, and clipboard recording orchestration.

### Views

- `LazyClip/Views/HistoryPanelView.swift`
  Top-level menu bar panel UI.
- `LazyClip/Views/HistoryListView.swift`
  Paged list with infinite-load trigger.
- `LazyClip/Views/HistoryRowView.swift`
  Row preview, time metadata, and delete action.
- `LazyClip/Views/PausedBannerView.swift`
  Lightweight paused-state indicator.
- `LazyClip/Views/SettingsView.swift`
  Pause toggle, history-limit picker, clear-all action.

### Tests

- `LazyClipTests/TestSupport/TemporaryDatabase.swift`
  Creates throwaway SQLite files for repository tests.
- `LazyClipTests/TestSupport/PasteboardSpy.swift`
  Fake pasteboard for monitor and state tests.
- `LazyClipTests/TestSupport/AppStateHarness.swift`
  Builds a temporary database plus fake pasteboard for `AppState` integration-style tests.
- `LazyClipTests/AppConfigurationTests.swift`
- `LazyClipTests/SettingsRepositoryTests.swift`
- `LazyClipTests/HistoryRepositoryTests.swift`
- `LazyClipTests/ClipboardMonitorTests.swift`
- `LazyClipTests/AppStateTests.swift`

### QA docs

- `docs/manual-testing/macos-clipboard-history-v1.md`
  Manual acceptance checklist matching the spec.

## Build and Test Conventions

- Use `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'` for compile verification.
- Use `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'` for the full unit suite.
- Prefer targeted `-only-testing:` runs while implementing each task.
- Commit after each task, not only at the very end.

## Task 1: Bootstrap the macOS Menu Bar Project

**Files:**
- Create: `LazyClip.xcodeproj/project.pbxproj`
- Create: `LazyClip/Info.plist`
- Create: `LazyClip/App/LazyClipApp.swift`
- Create: `LazyClip/App/AppConfiguration.swift`
- Test: `LazyClipTests/AppConfigurationTests.swift`

- [ ] **Step 1: Create the Xcode project and test target**

Create a macOS `App` project named `LazyClip` with a unit test target named `LazyClipTests`. Commit the generated project file, app target folder, and test target folder. Set the deployment target to macOS 14.0.

- [ ] **Step 2: Configure the app to run as a menu bar utility**

Add `LSUIElement` to `LazyClip/Info.plist` and point the app target at that file so the app launches without a Dock icon.

- [ ] **Step 3: Write the failing configuration test**

```swift
import XCTest
@testable import LazyClip

final class AppConfigurationTests: XCTestCase {
    func testDefaultsMatchSpec() {
        XCTAssertEqual(AppConfiguration.defaultHistoryLimit, 500)
        XCTAssertEqual(AppConfiguration.historyPageSize, 100)
        XCTAssertEqual(AppConfiguration.pasteboardPollInterval, 0.5)
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppConfigurationTests`

Expected: FAIL with `Cannot find 'AppConfiguration' in scope`.

- [ ] **Step 5: Implement the minimal app shell**

Create `LazyClip/App/AppConfiguration.swift`:

```swift
import Foundation

enum AppConfiguration {
    static let defaultHistoryLimit = 500
    static let historyPageSize = 100
    static let pasteboardPollInterval: TimeInterval = 0.5
}
```

Create `LazyClip/App/LazyClipApp.swift` with a placeholder menu bar scene and a placeholder settings scene:

```swift
import SwiftUI

@main
struct LazyClipApp: App {
    var body: some Scene {
        MenuBarExtra("LazyClip", systemImage: "paperclip") {
            Text("Loading…")
                .frame(width: 360, height: 480)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Settings")
                .frame(width: 320, height: 180)
                .padding()
        }
    }
}
```

- [ ] **Step 6: Run the targeted test and a build**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppConfigurationTests`

Expected: PASS with `Test Suite 'AppConfigurationTests' passed`.

Run: `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add LazyClip.xcodeproj LazyClip/Info.plist LazyClip/App/LazyClipApp.swift LazyClip/App/AppConfiguration.swift LazyClipTests/AppConfigurationTests.swift
git commit -m "chore: scaffold lazyclip menu bar app"
```

## Task 2: Add SQLite Bootstrap and Settings Persistence

**Files:**
- Create: `LazyClip/Models/AppSettings.swift`
- Create: `LazyClip/Persistence/ApplicationSupportPaths.swift`
- Create: `LazyClip/Persistence/DatabaseManager.swift`
- Create: `LazyClip/Persistence/SchemaMigrator.swift`
- Create: `LazyClip/Persistence/SettingsRepository.swift`
- Modify: `LazyClip.xcodeproj/project.pbxproj`
- Test: `LazyClipTests/TestSupport/TemporaryDatabase.swift`
- Test: `LazyClipTests/SettingsRepositoryTests.swift`

- [ ] **Step 1: Link SQLite and add the test helper**

Update the project to link `libsqlite3.tbd`. Add `TemporaryDatabase` so repository tests can create and dispose isolated SQLite files.

- [ ] **Step 2: Write the failing settings repository tests**

```swift
import XCTest
@testable import LazyClip

final class SettingsRepositoryTests: XCTestCase {
    func testFreshDatabaseLoadsSpecDefaults() throws {
        let db = try TemporaryDatabase()
        let repository = try SettingsRepository(databasePath: db.url)

        let settings = try repository.load()

        XCTAssertFalse(settings.isPaused)
        XCTAssertEqual(settings.historyLimit, 500)
    }

    func testSavingSettingsPersistsValues() throws {
        let db = try TemporaryDatabase()
        let repository = try SettingsRepository(databasePath: db.url)

        try repository.save(AppSettings(isPaused: true, historyLimit: 1000))

        let reloaded = try repository.load()
        XCTAssertTrue(reloaded.isPaused)
        XCTAssertEqual(reloaded.historyLimit, 1000)
    }
}
```

- [ ] **Step 3: Run the settings tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/SettingsRepositoryTests`

Expected: FAIL with missing `SettingsRepository`, `AppSettings`, and `TemporaryDatabase`.

- [ ] **Step 4: Implement the database bootstrap and settings repository**

Create `LazyClip/Models/AppSettings.swift`:

```swift
struct AppSettings: Equatable {
    var isPaused: Bool
    var historyLimit: Int
}
```

Create `LazyClip/Persistence/ApplicationSupportPaths.swift` to resolve `~/Library/Application Support/LazyClip/history.sqlite`.

Create `LazyClip/Persistence/DatabaseManager.swift` and `LazyClip/Persistence/SchemaMigrator.swift` to:

```sql
CREATE TABLE IF NOT EXISTS clipboard_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    captured_at INTEGER NOT NULL,
    last_recopied_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_clipboard_history_captured_at
ON clipboard_history (captured_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_clipboard_history_content_hash
ON clipboard_history (content_hash);

CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);
```

Create `LazyClip/Persistence/SettingsRepository.swift` with `load()` and `save(_:)`, seeding defaults when the table is empty.

- [ ] **Step 5: Run the targeted settings tests**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/SettingsRepositoryTests`

Expected: PASS with `Test Suite 'SettingsRepositoryTests' passed`.

- [ ] **Step 6: Commit**

```bash
git add LazyClip.xcodeproj LazyClip/Models/AppSettings.swift LazyClip/Persistence/ApplicationSupportPaths.swift LazyClip/Persistence/DatabaseManager.swift LazyClip/Persistence/SchemaMigrator.swift LazyClip/Persistence/SettingsRepository.swift LazyClipTests/TestSupport/TemporaryDatabase.swift LazyClipTests/SettingsRepositoryTests.swift
git commit -m "feat: add sqlite settings persistence"
```

## Task 3: Implement Core History Storage

**Files:**
- Create: `LazyClip/Models/ClipboardHistoryItem.swift`
- Create: `LazyClip/Persistence/HistoryRepository.swift`
- Test: `LazyClipTests/HistoryRepositoryTests.swift`

- [ ] **Step 1: Write the failing repository tests for insert, latest, delete, and clear**

```swift
import XCTest
@testable import LazyClip

final class HistoryRepositoryTests: XCTestCase {
    func testInsertAndFetchLatestRecord() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        let inserted = try repository.insert(content: "hello")
        let latest = try repository.fetchLatest()

        XCTAssertEqual(latest?.id, inserted.id)
        XCTAssertEqual(latest?.content, "hello")
    }

    func testDeleteRemovesSingleRecord() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        let item = try repository.insert(content: "to delete")
        try repository.delete(id: item.id)

        XCTAssertNil(try repository.fetchLatest())
    }

    func testClearRemovesAllRecords() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        _ = try repository.insert(content: "one")
        _ = try repository.insert(content: "two")
        try repository.clearAll()

        XCTAssertEqual(try repository.totalCount(), 0)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/HistoryRepositoryTests`

Expected: FAIL with missing `HistoryRepository` and `ClipboardHistoryItem`.

- [ ] **Step 3: Implement the history model and repository core**

Create `LazyClip/Models/ClipboardHistoryItem.swift`:

```swift
struct ClipboardHistoryItem: Identifiable, Equatable {
    let id: Int64
    let content: String
    let contentHash: String
    let capturedAt: Date
    let lastRecopiedAt: Date?
}
```

Create `LazyClip/Persistence/HistoryRepository.swift` with:

1. `insert(content:)`
2. `fetchLatest()`
3. `delete(id:)`
4. `clearAll()`
5. `totalCount()`

Use `CryptoKit` `SHA256` to derive `contentHash` so duplicate checks and future indexing stay cheap.

- [ ] **Step 4: Run the targeted repository tests**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/HistoryRepositoryTests`

Expected: PASS with `Test Suite 'HistoryRepositoryTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/Models/ClipboardHistoryItem.swift LazyClip/Persistence/HistoryRepository.swift LazyClipTests/HistoryRepositoryTests.swift
git commit -m "feat: add core clipboard history storage"
```

## Task 4: Add Paging, Search, Retention, and Re-Copy Metadata

**Files:**
- Create: `LazyClip/Models/HistoryPage.swift`
- Modify: `LazyClip/Persistence/HistoryRepository.swift`
- Modify: `LazyClipTests/HistoryRepositoryTests.swift`

- [ ] **Step 1: Extend the failing history tests for paging, search, trim, and re-copy timestamps**

Add tests like:

```swift
func testFetchPageReturnsNewestFirst() throws
func testSearchFiltersBySubstring() throws
func testTrimmingRemovesOldestRowsAboveLimit() throws
func testMarkRecopiedUpdatesTimestamp() throws
```

Representative search test:

```swift
func testSearchFiltersBySubstring() throws {
    let db = try TemporaryDatabase()
    let repository = try HistoryRepository(databasePath: db.url)
    _ = try repository.insert(content: "apple pie")
    _ = try repository.insert(content: "banana bread")

    let page = try repository.fetchPage(searchText: "apple", limit: 100, offset: 0)

    XCTAssertEqual(page.items.map(\.content), ["apple pie"])
    XCTAssertFalse(page.hasMore)
}
```

- [ ] **Step 2: Run the expanded history tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/HistoryRepositoryTests`

Expected: FAIL with missing `fetchPage`, `trimToLimit`, `markRecopied`, and `HistoryPage`.

- [ ] **Step 3: Implement paged queries and trim behavior**

Create `LazyClip/Models/HistoryPage.swift`:

```swift
struct HistoryPage: Equatable {
    let items: [ClipboardHistoryItem]
    let offset: Int
    let limit: Int
    let hasMore: Bool
}
```

Extend `HistoryRepository` with:

1. `fetchPage(searchText: String?, limit: Int, offset: Int) -> HistoryPage`
2. `trimToLimit(_ limit: Int)`
3. `markRecopied(id: Int64, at: Date = .now)`

Use `LIKE` queries for search and order by `captured_at DESC, id DESC`.

- [ ] **Step 4: Run the history tests again**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/HistoryRepositoryTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/Models/HistoryPage.swift LazyClip/Persistence/HistoryRepository.swift LazyClipTests/HistoryRepositoryTests.swift
git commit -m "feat: add paged history queries and retention"
```

## Task 5: Build the Pasteboard Adapter and Clipboard Monitor

**Files:**
- Create: `LazyClip/Clipboard/PasteboardClient.swift`
- Create: `LazyClip/Clipboard/SystemPasteboardClient.swift`
- Create: `LazyClip/Clipboard/ClipboardMonitor.swift`
- Test: `LazyClipTests/TestSupport/PasteboardSpy.swift`
- Test: `LazyClipTests/ClipboardMonitorTests.swift`

- [ ] **Step 1: Write the failing clipboard monitor tests**

```swift
import XCTest
@testable import LazyClip

final class ClipboardMonitorTests: XCTestCase {
    func testPollReturnsStringWhenChangeCountAdvances() throws {
        let pasteboard = PasteboardSpy()
        pasteboard.setReadValue("hello", changeCount: 1)
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        let value = monitor.pollOnce()

        XCTAssertEqual(value, "hello")
    }

    func testPollSkipsSelfWrittenClipboardValue() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        monitor.copyToPasteboard("self write")
        pasteboard.setReadValue("self write", changeCount: 1)

        XCTAssertNil(monitor.pollOnce())
    }
}
```

- [ ] **Step 2: Run the monitor tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/ClipboardMonitorTests`

Expected: FAIL with missing `ClipboardMonitor`, `PasteboardClient`, and `PasteboardSpy`.

- [ ] **Step 3: Implement the pasteboard abstractions**

Create `LazyClip/Clipboard/PasteboardClient.swift`:

```swift
protocol PasteboardClient {
    var changeCount: Int { get }
    func readString() -> String?
    func writeString(_ value: String)
}
```

Create `LazyClip/Clipboard/SystemPasteboardClient.swift` backed by `NSPasteboard.general`.

Create `LazyClip/Clipboard/ClipboardMonitor.swift` with:

1. `pollOnce() -> String?`
2. `copyToPasteboard(_ value: String)`
3. internal `lastSeenChangeCount`
4. one-value self-write suppression for the next matching poll

- [ ] **Step 4: Run the targeted clipboard tests**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/ClipboardMonitorTests`

Expected: PASS with `Test Suite 'ClipboardMonitorTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/Clipboard/PasteboardClient.swift LazyClip/Clipboard/SystemPasteboardClient.swift LazyClip/Clipboard/ClipboardMonitor.swift LazyClipTests/TestSupport/PasteboardSpy.swift LazyClipTests/ClipboardMonitorTests.swift
git commit -m "feat: add pasteboard monitor service"
```

## Task 6: Wire Repositories and Clipboard Flow into AppState

**Files:**
- Create: `LazyClip/App/AppContainer.swift`
- Create: `LazyClip/State/AppState.swift`
- Test: `LazyClipTests/TestSupport/AppStateHarness.swift`
- Test: `LazyClipTests/AppStateTests.swift`

- [ ] **Step 1: Write failing app-state tests for startup, pause handling, insert flow, and pagination**

```swift
import XCTest
@testable import LazyClip

final class AppStateTests: XCTestCase {
    func testStartupLoadsSettingsAndFirstPage() throws
    func testPausedStatePreventsRecording() throws
    func testSelectingItemCopiesItAndUpdatesRecopiedTimestamp() throws
    func testLoadNextPageAppendsResults() throws
}
```

Representative paused-state test:

```swift
func testPausedStatePreventsRecording() throws {
    let harness = try AppStateHarness.make()
    try harness.settingsRepository.save(AppSettings(isPaused: true, historyLimit: 500))

    let state = try harness.makeAppState()
    harness.pasteboard.setReadValue("secret", changeCount: 1)

    state.handleClipboardPoll()

    XCTAssertEqual(try harness.historyRepository.totalCount(), 0)
}
```

- [ ] **Step 2: Run the app-state tests to verify they fail**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests`

Expected: FAIL with missing `AppState` and `AppContainer`.

- [ ] **Step 3: Implement the live composition root and state layer**

Create `LazyClip/App/AppContainer.swift` that builds:

1. `ApplicationSupportPaths`
2. `DatabaseManager`
3. `SettingsRepository`
4. `HistoryRepository`
5. `ClipboardMonitor`
6. `AppState`

Create `LazyClip/State/AppState.swift` as `@MainActor final class AppState: ObservableObject` with:

1. `@Published var settings`
2. `@Published var searchText`
3. `@Published var items`
4. `@Published var isLoadingMore`
5. `@Published var storageErrorMessage`
6. `loadInitialData()`
7. `handleClipboardPoll()`
8. `loadNextPageIfNeeded(currentItem:)`
9. `select(item:)`
10. `delete(item:)`
11. `clearAll()`
12. `updatePauseState(_:)`
13. `updateHistoryLimit(_:)`

Behavior to enforce:

1. Do not insert when paused.
2. Ignore empty strings.
3. Suppress only consecutive duplicates by comparing against `fetchLatest()`.
4. After inserting, call `trimToLimit(settings.historyLimit)`.
5. After re-copying, call `markRecopied`.

- [ ] **Step 4: Run the app-state tests**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppStateTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/App/AppContainer.swift LazyClip/State/AppState.swift LazyClipTests/TestSupport/AppStateHarness.swift LazyClipTests/AppStateTests.swift
git commit -m "feat: connect app state to clipboard and storage"
```

## Task 7: Build the History Panel UI

**Files:**
- Create: `LazyClip/Views/HistoryPanelView.swift`
- Create: `LazyClip/Views/HistoryListView.swift`
- Create: `LazyClip/Views/HistoryRowView.swift`
- Create: `LazyClip/Views/PausedBannerView.swift`
- Modify: `LazyClip/App/LazyClipApp.swift`
- Modify: `LazyClip/State/AppState.swift`

- [ ] **Step 1: Replace the placeholder panel with the real SwiftUI surface**

Build `HistoryPanelView` with:

1. top bar title plus `SettingsLink`
2. optional `PausedBannerView`
3. searchable text field
4. paged list of history items
5. empty state when there are no rows

- [ ] **Step 2: Implement row rendering and delete affordance**

Create `HistoryRowView` so each row shows:

1. truncated multiline text preview
2. relative or formatted copy time
3. delete button separate from the row-tap target

Make the full row trigger `appState.select(item:)`.

- [ ] **Step 3: Add infinite scrolling behavior**

Create `HistoryListView` to call `loadNextPageIfNeeded(currentItem:)` from `onAppear` on the trailing rows. Keep the logic in `AppState`; the view should only forward events.

- [ ] **Step 4: Verify the app still builds**

Run: `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/Views/HistoryPanelView.swift LazyClip/Views/HistoryListView.swift LazyClip/Views/HistoryRowView.swift LazyClip/Views/PausedBannerView.swift LazyClip/App/LazyClipApp.swift LazyClip/State/AppState.swift
git commit -m "feat: add clipboard history panel ui"
```

## Task 8: Add the Settings Window and Finish App Wiring

**Files:**
- Create: `LazyClip/Views/SettingsView.swift`
- Modify: `LazyClip/App/LazyClipApp.swift`
- Modify: `LazyClip/State/AppState.swift`

- [ ] **Step 1: Build the settings view**

Implement a dedicated `SettingsView` with:

1. `Pause recording` toggle bound to `appState.settings.isPaused`
2. `Picker` with `100`, `500`, `1000`, `5000`
3. `Clear all history` destructive button with confirmation dialog
4. optional storage error copy if `storageErrorMessage` is non-nil

- [ ] **Step 2: Connect the SwiftUI `Settings` scene**

Replace the placeholder settings scene in `LazyClipApp` so it shows `SettingsView`, shares the same `AppState`, and remains a small focused settings window.

- [ ] **Step 3: Start clipboard polling from the live app**

In `LazyClipApp`, call `appState.loadInitialData()` on first appearance and drive polling with a repeating `Timer` or structured-concurrency loop using `AppConfiguration.pasteboardPollInterval`. Keep the polling loop in one place; do not let views create duplicate timers.

- [ ] **Step 4: Run the full test suite and a build**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: all tests PASS.

Run: `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add LazyClip/Views/SettingsView.swift LazyClip/App/LazyClipApp.swift LazyClip/State/AppState.swift
git commit -m "feat: add settings window and app lifecycle wiring"
```

## Task 9: Write the Manual QA Checklist and Run Final Verification

**Files:**
- Create: `docs/manual-testing/macos-clipboard-history-v1.md`

- [ ] **Step 1: Write the acceptance checklist**

Document these manual checks in `docs/manual-testing/macos-clipboard-history-v1.md`:

1. Launch app and confirm the menu bar icon appears.
2. Copy plain text and verify a new item appears near-immediately.
3. Copy the same text twice in a row and verify only one new record is added.
4. Search for a known substring and verify the filtered results.
5. Click a history item and verify it returns to the system clipboard.
6. Delete a single item and verify the list updates.
7. Change `history_limit` and verify old items trim when the limit is reduced.
8. Pause recording and verify new clipboard text is not recorded.
9. Clear all history and verify settings remain intact.
10. Restart the app and verify history plus settings persist.
11. Seed more than one page of data and verify initial panel open stays responsive while more rows load on demand.

- [ ] **Step 2: Run the automated verification**

Run: `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: PASS.

Run: `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Perform the manual QA checklist**

Launch from Xcode or Finder, then walk the checklist end-to-end on macOS 14+.

- [ ] **Step 4: Commit**

```bash
git add docs/manual-testing/macos-clipboard-history-v1.md
git commit -m "docs: add clipboard history qa checklist"
```

## Notes for the Implementer

1. Keep `AppKit` usage inside `SystemPasteboardClient.swift`; do not let it leak into SwiftUI views.
2. Do not add image history, global shortcuts, pinned items, or sync during this plan.
3. Prefer small helper methods over large view files; if `AppState` starts to sprawl, extract pure helpers without changing behavior.
4. When the full test suite passes, compare behavior back against `docs/superpowers/specs/2026-03-26-macos-clipboard-history-design.md` before calling the feature complete.
