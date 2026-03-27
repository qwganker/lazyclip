# Stable List Width Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the history and favorites list content width visually stable when a vertical scrollbar appears.

**Architecture:** Reuse the existing SwiftUI `List` implementation and add one shared width-preserving layout constant that both list views apply. Keep the fix at the list layer so the menu bar panel width, paging behavior, row actions, and page structure stay unchanged.

**Tech Stack:** Swift, SwiftUI, XCTest, Xcode macOS app target

---

## File Structure

- `LazyClip/App/AppConfiguration.swift`
  Add one shared list-width stabilization constant so both list views stay aligned and the value is defined in a single place.
- `LazyClip/Views/HistoryListView.swift`
  Apply the shared width-preserving layout rule to the history `List`.
- `LazyClip/Views/FavoritesListView.swift`
  Apply the same width-preserving layout rule to the favorites `List`.
- `LazyClipTests/AppConfigurationTests.swift`
  Extend configuration coverage for the new shared constant.

## Build and Test Conventions

- Use `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppConfigurationTests` for the targeted TDD loop.
- Use `xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'` for compile verification.
- Run the full suite with `xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'` before claiming completion.

## Task 1: Add a shared stable-width configuration value

**Files:**
- Modify: `LazyClip/App/AppConfiguration.swift`
- Modify: `LazyClipTests/AppConfigurationTests.swift`

- [ ] **Step 1: Write the failing configuration test**

Update `LazyClipTests/AppConfigurationTests.swift` to assert the new shared constant:

```swift
import XCTest
@testable import LazyClip

final class AppConfigurationTests: XCTestCase {
    func testDefaultsMatchSpec() {
        XCTAssertEqual(AppConfiguration.defaultHistoryLimit, 500)
        XCTAssertEqual(AppConfiguration.historyPageSize, 100)
        XCTAssertEqual(AppConfiguration.pasteboardPollInterval, 0.5)
        XCTAssertEqual(AppConfiguration.listScrollbarReservedWidth, 12)
    }
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppConfigurationTests
```

Expected: FAIL with an error similar to `Type 'AppConfiguration' has no member 'listScrollbarReservedWidth'`.

- [ ] **Step 3: Add the minimal shared configuration value**

Update `LazyClip/App/AppConfiguration.swift`:

```swift
import Foundation

enum AppConfiguration {
    static let defaultHistoryLimit = 500
    static let historyPageSize = 100
    static let pasteboardPollInterval: TimeInterval = 0.5
    static let listScrollbarReservedWidth: CGFloat = 12
}
```

- [ ] **Step 4: Import SwiftUI so the `CGFloat` constant compiles**

Make the file import explicit:

```swift
import SwiftUI

enum AppConfiguration {
    static let defaultHistoryLimit = 500
    static let historyPageSize = 100
    static let pasteboardPollInterval: TimeInterval = 0.5
    static let listScrollbarReservedWidth: CGFloat = 12
}
```

- [ ] **Step 5: Run the targeted test to verify it passes**

Run:

```bash
xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS' -only-testing:LazyClipTests/AppConfigurationTests
```

Expected: PASS with `Test Suite 'AppConfigurationTests' passed`.

- [ ] **Step 6: Commit**

```bash
git add LazyClip/App/AppConfiguration.swift LazyClipTests/AppConfigurationTests.swift
git commit -m "feat: add stable list width configuration"
```

## Task 2: Keep history and favorites list width stable when scrolling

**Files:**
- Modify: `LazyClip/Views/HistoryListView.swift`
- Modify: `LazyClip/Views/FavoritesListView.swift`

- [ ] **Step 1: Add the failing layout change to the history list**

Update `LazyClip/Views/HistoryListView.swift` so the `List` reserves stable trailing width instead of allowing scrollbar appearance to reduce visible content width:

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
        .safeAreaPadding(.trailing, AppConfiguration.listScrollbarReservedWidth)
        .listStyle(.plain)
        .contentMargins(.top, 2, for: .scrollContent)
    }
}
```

- [ ] **Step 2: Apply the same stable-width rule to favorites**

Update `LazyClip/Views/FavoritesListView.swift` with the same trailing reservation:

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
        .safeAreaPadding(.trailing, AppConfiguration.listScrollbarReservedWidth)
        .listStyle(.plain)
        .contentMargins(.top, 2, for: .scrollContent)
    }
}
```

- [ ] **Step 3: Build the app to verify the view changes compile**

Run:

```bash
xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manually verify stable width behavior in History and Favorites**

Run the app from Xcode or the built product and verify:

1. Open History with only a few rows and note the visible content width.
2. Add enough clipboard entries to make History scroll.
3. Confirm the visible row width stays stable after the scrollbar appears.
4. Favorite enough rows to make Favorites scroll.
5. Confirm Favorites keeps the same stable width behavior.
6. Confirm history delete, favorite toggle, item selection, and pagination still work.

- [ ] **Step 5: Run the full test suite**

Run:

```bash
xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add LazyClip/Views/HistoryListView.swift LazyClip/Views/FavoritesListView.swift
git commit -m "fix: keep list width stable while scrolling"
```
