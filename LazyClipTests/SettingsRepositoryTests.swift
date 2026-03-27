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
