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

    func testFetchPageReturnsNewestFirst() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        _ = try repository.insert(content: "first")
        _ = try repository.insert(content: "second")
        _ = try repository.insert(content: "third")

        let page = try repository.fetchPage(searchText: nil, limit: 2, offset: 0)

        XCTAssertEqual(page.items.map(\.content), ["third", "second"])
        XCTAssertEqual(page.offset, 0)
        XCTAssertEqual(page.limit, 2)
        XCTAssertTrue(page.hasMore)
    }

    func testSearchFiltersBySubstring() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        _ = try repository.insert(content: "apple pie")
        _ = try repository.insert(content: "banana bread")

        let page = try repository.fetchPage(searchText: "apple", limit: 100, offset: 0)

        XCTAssertEqual(page.items.map(\.content), ["apple pie"])
        XCTAssertFalse(page.hasMore)
    }

    func testTrimmingRemovesOldestRowsAboveLimit() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)

        _ = try repository.insert(content: "one")
        _ = try repository.insert(content: "two")
        _ = try repository.insert(content: "three")

        try repository.trimToLimit(2)

        let page = try repository.fetchPage(searchText: nil, limit: 10, offset: 0)
        XCTAssertEqual(page.items.map(\.content), ["three", "two"])
        XCTAssertEqual(try repository.totalCount(), 2)
    }

    func testMarkRecopiedUpdatesTimestamp() throws {
        let db = try TemporaryDatabase()
        let repository = try HistoryRepository(databasePath: db.url)
        let inserted = try repository.insert(content: "hello")
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        try repository.markRecopied(id: inserted.id, at: timestamp)

        let latest = try repository.fetchLatest()
        XCTAssertEqual(latest?.lastRecopiedAt, timestamp)
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
