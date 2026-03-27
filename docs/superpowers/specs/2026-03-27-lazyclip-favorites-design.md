# LazyClip Favorites Feature Design

- Date: 2026-03-27
- Status: Approved for planning
- Target platform: macOS 14+
- Language: Swift
- UI stack: SwiftUI
- Persistence: SQLite

## 1. Product Summary

This design adds a lightweight favorites capability to LazyClip. Users can mark clipboard history items as favorites, browse those items in a dedicated favorites page inside the existing menu bar window, and remove items from favorites without deleting the underlying clipboard history.

The feature is intentionally narrow. Favorites are a secondary organizational layer on top of clipboard history, not a separate storage system and not a replacement for history management.

## 2. Goals

The feature must:

1. Let users favorite any existing history item from the history list.
2. Let users open a dedicated favorites page inside the current menu bar window.
3. Show favorites ordered by most recently favorited first.
4. Let users remove a favorite from either the history page or the favorites page.
5. Keep the original history item intact when a favorite is removed.
6. Keep favorite state visually synchronized between history and favorites views.
7. Preserve the existing history behavior for re-copy, search, deletion, and retention.

## 3. Non-Goals

This feature does not add:

1. Pinned items mixed into the top of the history list.
2. Manual drag-and-drop ordering of favorites.
3. Separate storage of clipboard content for favorites.
4. A favorites-only delete action that removes history records.
5. Tags, folders, or additional item organization.
6. New windows or a separate app shell.

## 4. User Experience Direction

Favorites are a separate view, not a sort mode and not just a visual badge.

The menu bar window should support three pages:

1. History
2. Favorites
3. Settings

The history page remains the default landing page. Favorites should feel like a focused secondary list for quick access to saved items.

### 4.1 History Page

Each history row keeps its current primary action:

- clicking the row body re-copies the item to the system clipboard

Each row also exposes two secondary actions on the right:

1. Favorite / unfavorite star button
2. Delete button

Star behavior:

- hollow star = not favorited
- filled star = favorited
- clicking the star toggles favorite state immediately
- toggling favorite state does not trigger re-copy

### 4.2 Favorites Page

The favorites page displays only favorited history items.

Each favorites row supports:

- clicking the row body to re-copy the item
- clicking the star to remove it from favorites

The favorites page does not show a delete button.

When a user removes a favorite from the favorites page:

1. the favorite relationship is deleted
2. the item immediately disappears from the favorites list
3. the underlying history record remains intact
4. the history page reflects the new hollow-star state for that item

### 4.3 Empty State

If there are no favorites, the favorites page should show a dedicated empty state explaining that users can star items from history to save them.

## 5. Data Model

Favorites should be stored in a separate table rather than embedded in `clipboard_history`.

### 5.1 `favorite_items`

Schema:

- `history_item_id INTEGER PRIMARY KEY`
- `favorited_at INTEGER NOT NULL`

Semantics:

1. Each history item can be favorited at most once.
2. `favorited_at` records when the favorite relationship was created.
3. Favorites reference existing history rows rather than duplicating clipboard content.

Recommended index behavior:

- the primary key enforces uniqueness by `history_item_id`
- add an index on `favorited_at DESC, history_item_id DESC` to support favorites-page ordering

## 6. Architecture and Boundaries

The favorites feature should keep repository responsibilities separate.

### 6.1 `HistoryRepository`

`HistoryRepository` remains responsible only for clipboard history records:

- insert
- page fetch
- search
- mark recopied
- delete history item
- clear all history
- retention trimming

It should not absorb favorites logic.

### 6.2 `FavoritesRepository`

Add a dedicated `FavoritesRepository` file responsible only for favorite relationships.

Recommended responsibilities:

1. Add a favorite for a history item.
2. Remove a favorite for a history item.
3. Fetch a favorites page ordered by `favorited_at DESC`.
4. Fetch favorite ids for a provided set of history ids.
5. Clear all favorite relationships.

This repository uses the same SQLite database file as the rest of the app, but owns its own table and queries.

### 6.3 Application State

`AppState` coordinates cross-repository workflows and UI synchronization.

It should own:

- current page selection: history / favorites / settings
- existing history state
- favorites list state
- a lightweight in-memory representation of which history items are favorited, such as `Set<Int64>`

`AppState` is responsible for:

1. loading history rows and their favorite status together
2. loading favorites rows for the favorites page
3. toggling favorite state
4. keeping history and favorites views in sync after user actions
5. coordinating history deletion and clear-all behavior with favorites cleanup

## 7. Query and View-Model Strategy

The UI should treat favorite state as an attached relationship rather than mutating the history model itself.

Recommended approach:

1. Load a history page from `HistoryRepository`.
2. Ask `FavoritesRepository` for favorite ids matching the loaded history-item ids.
3. Store those ids in app state.
4. Render star state based on membership in that set.

For the favorites page:

1. Fetch favorites ordered by `favorited_at DESC`.
2. Join each favorite relationship to its backing `clipboard_history` row in SQLite.
3. Return displayable items for the favorites list.

This keeps the data model normalized while still letting the UI render full row content.

## 8. Core Behavior Rules

### 8.1 Favoriting from History

When a user clicks the hollow star on a history row:

1. create or upsert a favorite relationship for that history item
2. set `favorited_at` to the current timestamp
3. update in-memory favorite state so the history row becomes a filled star
4. make the item appear in favorites ordered by most recently favorited first

### 8.2 Removing a Favorite from History

When a user clicks the filled star on a history row:

1. remove the favorite relationship
2. update in-memory favorite state so the row becomes a hollow star
3. remove the item from the favorites page data if it is currently loaded
4. do not delete the history record

### 8.3 Removing a Favorite from Favorites

When a user clicks the filled star on a favorites row:

1. remove the favorite relationship
2. immediately remove that row from the visible favorites list
3. keep the history record unchanged
4. reflect the hollow-star state on the history page

### 8.4 Re-Copy Behavior

Re-copy behavior remains unchanged:

- clicking the row body on either history or favorites re-copies the item
- re-copying a favorite does not remove it from favorites
- re-copying must still avoid creating a duplicate history entry through the existing self-write ignore mechanism

### 8.5 History Deletion

Deleting a history row from the history page should also remove its favorite relationship if one exists.

This is coordinated by `AppState`, not hidden inside `HistoryRepository`.

Result:

1. the history row is deleted
2. any matching favorite relationship is deleted
3. the item no longer appears in favorites
4. in-memory favorite state is updated accordingly

### 8.6 Clear All History

When the user clears all history:

1. all history rows are deleted
2. all favorite relationships are deleted
3. both history and favorites UI state are cleared

This remains a coordinated application-layer action.

## 9. Error Handling

The feature should reuse the current error handling approach.

Guidelines:

1. Repository methods throw on failure.
2. `AppState` catches failures and updates `storageErrorMessage`.
3. Favorite UI should not optimistically claim success if persistence fails.
4. If a coordinated action touches both history and favorites and one part fails, the action should be surfaced as failed rather than silently leaving inconsistent UI state.

## 10. Testing Strategy

### 10.1 `FavoritesRepositoryTests`

Cover:

1. adding a favorite relationship
2. preventing duplicate favorites for the same history item
3. removing a favorite relationship
4. fetching favorites ordered by `favorited_at DESC`
5. fetching favorite ids for a supplied history-id set
6. clearing all favorite relationships

### 10.2 `AppStateTests`

Cover:

1. history rows render correct favorite state after initial load
2. favoriting from history updates the star state
3. unfavoriting from history updates the star state
4. favorites page loads favorited items
5. unfavoriting from favorites removes the row from the favorites list only
6. deleting a history row removes any related favorite relationship
7. clear-all empties both history and favorites state

### 10.3 View Scope

No new UI-test layer is required for the first implementation. The feature can continue to rely on repository and app-state tests, with SwiftUI views staying thin and action-forwarding only.

## 11. Implementation Notes

To minimize disruption to the current codebase:

1. Add a new `FavoritesRepository.swift` rather than expanding `HistoryRepository`.
2. Extend schema migration to create the `favorite_items` table and sorting index.
3. Keep favorites state separate from the persistence model for history rows.
4. Reuse the current menu bar window architecture and page-switching pattern in `HistoryPanelView`.
5. Keep the first release visually simple and behaviorally explicit.

## 12. Final Design Decision

Approved implementation direction:

- Use a separate `favorite_items` SQLite table.
- Add a dedicated `FavoritesRepository`.
- Add a favorites page inside the existing menu bar window.
- Show star + delete in history rows.
- Show only the star in favorites rows.
- Removing a favorite never deletes the underlying history record.
- Favorites are ordered by most recently favorited first.
- Synchronization between pages is coordinated in `AppState`.
