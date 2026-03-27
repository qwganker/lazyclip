# macOS Clipboard History Tool Design

- Date: 2026-03-26
- Status: Approved for planning
- Target platform: macOS 14+
- Language: Swift
- UI stack: SwiftUI
- Clipboard access: `NSPasteboard` via a dedicated service module
- Persistence: SQLite

## 1. Product Summary

This project is a lightweight macOS clipboard history tool focused on text-only history for the first release. The app lives in the menu bar, opens a custom SwiftUI panel, records copied text locally, supports search and re-copy, and exposes low-frequency management actions in a settings view.

The first release is intended for small-scale dogfooding and friend/test-user trial use. It should feel stable, native, and fast before any advanced features are added.

## 2. Goals

The first release must:

1. Record copied plain text on macOS.
2. Persist clipboard history locally across app restarts.
3. Let users open a menu bar panel and quickly find previous items.
4. Let users click a history item to copy it back to the system clipboard.
5. Let users delete single items.
6. Let users clear all history from settings with confirmation.
7. Let users pause and resume recording from settings.
8. Let users configure the maximum retained history count.
9. Stay responsive even when the database contains many records.

## 3. Non-Goals

The first release explicitly does not include:

1. Image clipboard history.
2. File or path clipboard history.
3. Automatic paste after selecting a record.
4. Global shortcut invocation.
5. Favorites or pinned items.
6. Cloud sync.
7. Rich text preservation.
8. Multiple windows or a full main app shell.

## 4. User Experience Direction

The app is optimized around one high-frequency action: finding an older copied text and putting it back on the clipboard quickly.

The main panel should stay focused on:

1. Opening quickly from the menu bar.
2. Searching recent history immediately.
3. Re-copying a selected entry with one click.

Low-frequency controls belong in settings:

1. Pause recording.
2. History retention limit.
3. Clear all history.

If recording is paused, the main panel should still work for browsing existing data, but it should show a lightweight paused status so the user does not forget recording is disabled.

## 5. Platform and Technical Constraints

1. The app targets macOS 14+.
2. The UI should be fully implemented in SwiftUI.
3. Clipboard access must use `NSPasteboard`, which requires `import AppKit`.
4. `AppKit` use is limited to clipboard access only; menu bar presentation and settings UI should remain SwiftUI-first.
5. The app should be suitable for distribution to test users, so behavior must be predictable and local-only.

## 6. Architecture Overview

The system is split into four layers:

### 6.1 Presentation

SwiftUI views render the menu bar panel and settings screen. Views display state and trigger user actions, but do not talk directly to SQLite or `NSPasteboard`.

Core view surfaces:

1. `LazyClipApp`
2. `HistoryPanelView`
3. `HistoryListView`
4. `SettingsView`

`LazyClipApp` should use a `MenuBarExtra` entry in window-style presentation so the history surface behaves like a lightweight panel rather than a nested system menu.

### 6.2 Application State

An application state layer coordinates view events and service calls.

Recommended core types:

1. `HistoryViewModel`
2. `SettingsViewModel` or a shared `AppState`

Responsibilities:

1. Load initial history page.
2. Load additional history pages on demand.
3. Apply search queries.
4. Trigger re-copy actions.
5. Reflect pause state and settings changes.
6. Surface storage or clipboard errors into user-facing status.

### 6.3 Services

The service layer contains business-facing interfaces:

1. `ClipboardService`
2. `HistoryRepository`
3. `SettingsRepository`

`ClipboardService` polls `NSPasteboard.general.changeCount`, reads plain text when content changes, and ignores unsupported clipboard types.

`HistoryRepository` owns history CRUD, paging, search, deduplication checks, and retention trimming.

`SettingsRepository` persists and retrieves app settings such as pause state and history limit.

### 6.4 Persistence

SQLite is the single source of truth for stored clipboard history and app settings.

The database file should be placed in the app's local application support directory. The app should create the directory and database on first launch.

## 7. Data Model

### 7.1 `clipboard_history`

Recommended schema:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `content TEXT NOT NULL`
- `content_hash TEXT NOT NULL`
- `captured_at INTEGER NOT NULL`
- `last_recopied_at INTEGER NULL`

Notes:

1. `content` stores plain text only.
2. `content_hash` supports lightweight duplicate checks.
3. `captured_at` and `last_recopied_at` are stored as Unix timestamps.

Indexes:

1. Index on `captured_at DESC`
2. Index on `content_hash`

### 7.2 `app_settings`

Recommended schema:

- `key TEXT PRIMARY KEY`
- `value TEXT NOT NULL`
- `updated_at INTEGER NOT NULL`

Initial keys:

1. `is_paused`
2. `history_limit`

This key-value structure keeps the first release simple while allowing additional settings later without a schema rewrite.

## 8. Data Access and Loading Strategy

The app should not load the full history table into memory at startup.

Instead:

1. On launch, fetch only the newest `100` records for the initial page.
2. When the user scrolls near the end of the visible list, fetch the next page of `100`.
3. Search results should also be paged from SQLite rather than filtering an in-memory full dataset.
4. The total history count can be fetched by a separate lightweight count query.

This keeps launch and panel-open behavior fast even if the user sets a large retention limit such as `5000`.

## 9. Core Behavior Rules

### 9.1 App Launch

On startup, the app should:

1. Open or create the SQLite database.
2. Load settings.
3. Load the initial history page.
4. Start clipboard monitoring only after settings are available.

This order ensures a persisted paused state is honored before any new clipboard content is recorded.

### 9.2 Clipboard Monitoring

Clipboard monitoring should use polling against `NSPasteboard.general.changeCount`.

Recommended first-release polling cadence:

- Check every `0.5` seconds

This is fast enough for a clipboard history utility while remaining simple to implement and reason about for a first release.

When a change is detected:

1. If recording is paused, ignore the change.
2. Read plain text only.
3. Ignore empty text.
4. Ignore unsupported clipboard types.
5. Ignore immediately repeated identical text if it matches the newest stored record.
6. Persist accepted text as a new history record.
7. Enforce the configured retention limit after insertion.

Deduplication rule for the first release:

- Only consecutive identical copies are suppressed.
- The same text may be stored again later if other items happened in between.

### 9.3 Re-Copying a History Item

When the user selects a history item:

1. Write its text back to the system clipboard.
2. Update `last_recopied_at`.
3. Close the menu bar panel after the action completes.

The app must not record its own re-copy action as a fresh history entry. `ClipboardService` should therefore maintain a short-lived self-write ignore mechanism.

### 9.4 Search

The first release can implement search with SQLite `LIKE` queries.

This is sufficient because:

1. The initial scope is plain text only.
2. Fuzzy ranking is unnecessary for the first release.
3. A later release can introduce a better indexing strategy without changing the UI contract.

### 9.5 Deletion and Clearing

Supported record management:

1. Delete a single history item from the list.
2. Clear all history from settings.

Single-item delete should happen immediately.

Clear-all should require a confirmation step because it is destructive.

### 9.6 Settings

The settings view must include:

1. `Pause recording` toggle
2. `History limit` picker
3. `Clear all history` action

Recommended default:

- `history_limit = 500`

Recommended first-release picker options:

1. `100`
2. `500`
3. `1000`
4. `5000`

The selected history limit must be persisted and enforced after each insertion. If a user lowers the limit below the current record count, the oldest extra records should be removed automatically.

## 10. UI Structure

### 10.1 Menu Bar Entry

The app appears as a menu bar extra. Opening it shows a custom SwiftUI panel rather than a full window-based workflow.

### 10.2 Main Panel

The main panel contains:

1. A compact top bar with app identity and a settings entry.
2. A search field for live filtering.
3. A paged history list ordered newest first.

Each history item shows:

1. A compact text preview
2. Copy time metadata
3. A delete affordance

Clicking the row re-copies the item.

### 10.3 Settings View

The settings surface contains:

1. Pause recording toggle
2. History limit control
3. Clear all history button with confirmation

The settings entry should open a dedicated small settings window, not an inline expander inside the history panel. This keeps the main surface focused on search and reuse.

If recording is paused, the main panel should show a clear but lightweight paused indicator.

### 10.4 Empty State

If no history exists yet, the panel should display a short explanation that copied text will appear there.

## 11. Error Handling and Edge Cases

1. If clipboard text cannot be read, skip the event and continue running.
2. If the clipboard contains non-text data, ignore it.
3. If the database fails to open or write, the app should enter a visible degraded state rather than crashing silently.
4. If settings cannot be loaded, default values may be used only if the database is otherwise healthy; the app should still surface that settings recovery occurred.
5. Self-written clipboard values from a re-copy action must not create duplicate history records.
6. Retention trimming should happen silently after inserts.

The first release should prefer resilience and clarity over elaborate recovery logic.

## 12. Testing Strategy

### 12.1 Repository Tests

Cover:

1. Insert history record
2. Load latest page in descending time order
3. Search with paging
4. Delete single record
5. Clear all records
6. Enforce retention limit

### 12.2 State / ViewModel Tests

Cover:

1. Paused mode blocks inserts
2. Consecutive duplicate suppression
3. Re-copy updates state and clipboard write path
4. Self-write ignore logic
5. Settings changes propagate correctly

### 12.3 Manual Integration Verification

Because clipboard behavior and menu bar presentation depend on the OS environment, a short manual verification checklist is required for each release candidate.

## 13. Release 1 Acceptance Criteria

The first release is considered acceptable when all of the following are true:

1. The menu bar icon appears on launch and opens the history panel.
2. Copying plain text causes a new history item to appear near-immediately.
3. Consecutive duplicate copies do not create duplicate records.
4. Search filters existing history correctly.
5. Clicking a history item puts it back on the system clipboard.
6. Deleting a single item updates the list immediately.
7. Changing `history_limit` in settings persists and takes effect.
8. Enabling `Pause recording` prevents new clipboard text from being recorded.
9. Clearing all history removes stored items but keeps settings.
10. Restarting the app restores history and settings.
11. When the database contains many records, opening the panel still shows the first page quickly.

## 14. Future Extensions

Deliberately postponed until after the first release:

1. Image support
2. Global shortcut
3. Favorites and pinning
4. Richer search
5. Export and import
6. Sync

This keeps the first release narrow, testable, and realistic for a Swift + macOS menu bar app.
