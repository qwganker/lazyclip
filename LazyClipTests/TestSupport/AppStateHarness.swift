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
