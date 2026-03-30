import XCTest
@testable import LazyClip

@MainActor
final class AppStateTests: XCTestCase {
    func testLoadInitialDataLoadsPersistedSettingsAndFirstPage() throws {
        let harness = try AppStateHarness()
        try harness.settingsRepository.save(AppSettings(isPaused: true, historyLimit: 250, imageSizeLimitMB: 10))
        _ = try harness.historyRepository.insert(content: "first")
        _ = try harness.historyRepository.insert(content: "second")

        let state = harness.makeAppState()
        try state.loadInitialData()

        XCTAssertEqual(state.settings, AppSettings(isPaused: true, historyLimit: 250, imageSizeLimitMB: 10))
        XCTAssertEqual(state.items.map(\.content), ["second", "first"])
        XCTAssertFalse(state.isLoadingMore)
        XCTAssertNil(state.storageErrorMessage)
    }

    func testHandleClipboardPollDoesNotInsertWhenPaused() throws {
        let harness = try AppStateHarness()
        try harness.settingsRepository.save(AppSettings(isPaused: true, historyLimit: 500, imageSizeLimitMB: 10))
        let state = harness.makeAppState()
        try state.loadInitialData()

        harness.pasteboard.setReadValue("paused value", changeCount: 1)
        try state.handleClipboardPoll()

        XCTAssertEqual(try harness.historyRepository.totalCount(), 0)
        XCTAssertTrue(state.items.isEmpty)
    }

    func testSelectCopiesItemAndMarksItRecopied() throws {
        let harness = try AppStateHarness()
        let inserted = try harness.historyRepository.insert(content: "copy me")
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.select(item: inserted)

        XCTAssertEqual(harness.pasteboard.lastWrittenValue, "copy me")
        XCTAssertEqual(try harness.historyRepository.fetchLatest()?.id, inserted.id)
        XCTAssertNotNil(try harness.historyRepository.fetchLatest()?.lastRecopiedAt)
        XCTAssertNotNil(state.items.first?.lastRecopiedAt)
    }

    func testLoadNextPageIfNeededAppendsResults() throws {
        let harness = try AppStateHarness()
        for index in 0..<(AppConfiguration.historyPageSize + 2) {
            _ = try harness.historyRepository.insert(content: "item \(index)")
        }

        let state = harness.makeAppState()
        try state.loadInitialData()

        XCTAssertEqual(state.items.count, AppConfiguration.historyPageSize)

        try state.loadNextPageIfNeeded(currentItem: state.items.last)

        XCTAssertEqual(state.items.count, AppConfiguration.historyPageSize + 2)
        XCTAssertEqual(state.items.first?.content, "item \(AppConfiguration.historyPageSize + 1)")
        XCTAssertEqual(state.items.last?.content, "item 0")
    }

    func testHandleClipboardPollInsertsAndTrimsToConfiguredLimit() throws {
        let harness = try AppStateHarness()
        try harness.settingsRepository.save(AppSettings(isPaused: false, historyLimit: 2, imageSizeLimitMB: 10))
        _ = try harness.historyRepository.insert(content: "one")
        _ = try harness.historyRepository.insert(content: "two")

        let state = harness.makeAppState()
        try state.loadInitialData()
        harness.pasteboard.setReadValue("three", changeCount: 1)

        try state.handleClipboardPoll()

        XCTAssertEqual(try harness.historyRepository.totalCount(), 2)
        XCTAssertEqual(state.items.map(\.content), ["three", "two"])
    }

    func testHandleClipboardPollSuppressesOnlyConsecutiveDuplicates() throws {
        let harness = try AppStateHarness()
        _ = try harness.historyRepository.insert(content: "A")

        let state = harness.makeAppState()
        try state.loadInitialData()

        harness.pasteboard.setReadValue("A", changeCount: 1)
        try state.handleClipboardPoll()
        XCTAssertEqual(try harness.historyRepository.totalCount(), 1)

        harness.pasteboard.setReadValue("B", changeCount: 2)
        try state.handleClipboardPoll()
        XCTAssertEqual(try harness.historyRepository.totalCount(), 2)

        harness.pasteboard.setReadValue("A", changeCount: 3)
        try state.handleClipboardPoll()
        XCTAssertEqual(try harness.historyRepository.totalCount(), 3)
        XCTAssertEqual(state.items.map(\.content), ["A", "B", "A"])
    }

    func testDeleteAndClearAllKeepVisibleStateInSync() throws {
        let harness = try AppStateHarness()
        let first = try harness.historyRepository.insert(content: "first")
        _ = try harness.historyRepository.insert(content: "second")
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.delete(item: first)
        XCTAssertEqual(state.items.map(\.content), ["second"])

        try state.clearAll()
        XCTAssertTrue(state.items.isEmpty)
        XCTAssertEqual(try harness.historyRepository.totalCount(), 0)
    }

    func testUpdateHistoryLimitPersistsAndTrimsExistingRows() throws {
        let harness = try AppStateHarness()
        let one = try harness.historyRepository.insert(content: "one")
        let two = try harness.historyRepository.insert(content: "two")
        _ = try harness.historyRepository.insert(content: "three")
        try harness.favoritesRepository.addFavorite(historyItemID: one.id)
        try harness.favoritesRepository.addFavorite(historyItemID: two.id)
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.updateHistoryLimit(2)

        XCTAssertEqual(state.settings.historyLimit, 2)
        XCTAssertEqual(try harness.settingsRepository.load().historyLimit, 2)
        XCTAssertEqual(try harness.historyRepository.totalCount(), 2)
        XCTAssertEqual(state.items.map(\.content), ["three", "two"])
    }

    func testUpdateSearchTextReloadsFilteredFirstPage() throws {
        let harness = try AppStateHarness()
        _ = try harness.historyRepository.insert(content: "apple pie")
        _ = try harness.historyRepository.insert(content: "banana bread")
        _ = try harness.historyRepository.insert(content: "green apple")
        let state = harness.makeAppState()
        try state.loadInitialData()

        try state.updateSearchText(" apple ")

        XCTAssertEqual(state.searchText, " apple ")
        XCTAssertEqual(state.items.map(\.content), ["green apple", "apple pie"])
    }

    func testLoadNextPageUsesActiveSearchQuery() throws {
        let harness = try AppStateHarness()
        for index in 0..<(AppConfiguration.historyPageSize + 2) {
            _ = try harness.historyRepository.insert(content: "apple \(index)")
        }
        _ = try harness.historyRepository.insert(content: "banana only")

        let state = harness.makeAppState()
        try state.loadInitialData()
        try state.updateSearchText("apple")

        XCTAssertEqual(state.items.count, AppConfiguration.historyPageSize)
        XCTAssertTrue(state.items.allSatisfy { $0.content.contains("apple") })

        try state.loadNextPageIfNeeded(currentItem: state.items.last)

        XCTAssertEqual(state.items.count, AppConfiguration.historyPageSize + 2)
        XCTAssertTrue(state.items.allSatisfy { $0.content.contains("apple") })
        XCTAssertEqual(state.items.last?.content, "apple 0")
    }

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
}
