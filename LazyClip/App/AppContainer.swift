import Foundation

@MainActor
struct AppContainer {
    let appState: AppState

    init() throws {
        let paths = try ApplicationSupportPaths()
        let settingsRepository = try SettingsRepository(databasePath: paths.databaseURL)
        let historyRepository = try HistoryRepository(databasePath: paths.databaseURL)
        let favoritesRepository = try FavoritesRepository(databasePath: paths.databaseURL)
        let clipboardMonitor = ClipboardMonitor(
            pasteboard: SystemPasteboardClient(),
            pollInterval: AppConfiguration.pasteboardPollInterval
        )

        appState = AppState(
            settingsRepository: settingsRepository,
            historyRepository: historyRepository,
            favoritesRepository: favoritesRepository,
            clipboardMonitor: clipboardMonitor
        )
    }
}
