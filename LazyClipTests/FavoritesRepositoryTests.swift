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
