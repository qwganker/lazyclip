# Stable List Width Design

- Date: 2026-03-27
- Status: Drafted for approval
- Scope: History/Favorites list width stability in the menu bar panel

## Context

When the history or favorites dataset grows enough to require vertical scrolling, the SwiftUI `List` shows a scrollbar and the visible content area becomes narrower. This makes the list feel like it shrinks after enough items are loaded, and the effect is more noticeable in history because rows also contain trailing action buttons.

The goal of this change is to keep the list width visually stable as item count grows, without changing the outer menu bar panel width, paging behavior, or row interactions.

## Problem

Both pages already share the same outer panel shell and nearly identical `List` styling, but `List` reduces the effective content area when the scrollbar appears. The current implementation does not reserve stable trailing space for that state, so the rows appear narrower once scrolling is needed.

## Recommended approach

Use a shared list-width stabilization strategy in both list views:

1. Keep the outer panel width unchanged.
2. Apply the same stable trailing space strategy to `HistoryListView` and `FavoritesListView` so the visible content width does not change when the scrollbar appears.
3. Keep the change localized to the list layer instead of replacing `List` or changing pagination behavior.

This is the smallest change that addresses the root cause while preserving the existing architecture.

## Files to modify

- `LazyClip/Views/HistoryListView.swift`
- `LazyClip/Views/FavoritesListView.swift`

## Existing code to reuse

- Shared list styling pattern in `HistoryListView` and `FavoritesListView`
- Shared row rendering through `HistoryRowView`
- Shared page shell in `HistoryPanelView`

## Implementation notes

- Introduce the same width-preserving layout rule in both list views.
- Prefer a single constant/value so both pages stay visually aligned.
- Do not change `HistoryRowView` unless the list-level fix alone proves insufficient.
- Do not change panel sizing in `HistoryPanelView`.
- Do not replace `List` with another scrolling container.

## Verification

1. Build the app with:
   - `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`
2. Run relevant tests:
   - `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'`
3. Manual verification in the running app:
   - Open History with only a few items and note visible row width.
   - Add enough history items to trigger the scrollbar.
   - Confirm the visible list width does not appear to shrink.
   - Switch to Favorites, add enough favorites to trigger the scrollbar, and confirm the same stability.
   - Confirm paging, selection, favorite toggle, and delete continue to work.
