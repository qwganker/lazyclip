import Foundation

@MainActor
final class AppState: ObservableObject {
    enum Page {
        case history
        case favorites
        case settings
    }

    @Published var settings: AppSettings
    @Published var searchText: String
    @Published var items: [ClipboardHistoryItem]
    @Published var favoriteItems: [FavoriteHistoryItem]
    @Published var currentPage: Page
    @Published var isLoadingMore: Bool
    @Published var isLoadingMoreFavorites: Bool
    @Published var storageErrorMessage: String?

    private let settingsRepository: SettingsRepository
    private let historyRepository: HistoryRepository
    private let favoritesRepository: FavoritesRepository
    private let clipboardMonitor: ClipboardMonitor
    private(set) var favoritedItemIDs: Set<Int64>
    private var currentOffset: Int
    private var hasMorePages: Bool
    private var favoriteOffset: Int
    private var favoriteHasMorePages: Bool

    init(
        settingsRepository: SettingsRepository,
        historyRepository: HistoryRepository,
        favoritesRepository: FavoritesRepository,
        clipboardMonitor: ClipboardMonitor
    ) {
        self.settingsRepository = settingsRepository
        self.historyRepository = historyRepository
        self.favoritesRepository = favoritesRepository
        self.clipboardMonitor = clipboardMonitor
        settings = AppSettings(isPaused: false, historyLimit: AppConfiguration.defaultHistoryLimit)
        searchText = ""
        items = []
        favoriteItems = []
        currentPage = .history
        isLoadingMore = false
        isLoadingMoreFavorites = false
        storageErrorMessage = nil
        favoritedItemIDs = []
        currentOffset = 0
        hasMorePages = false
        favoriteOffset = 0
        favoriteHasMorePages = false
    }

    func loadInitialData() throws {
        settings = try settingsRepository.load()
        try reloadFirstPage()
        try loadFavorites()
    }

    func handleClipboardPoll() throws {
        guard let value = clipboardMonitor.pollOnce() else {
            return
        }

        guard settings.isPaused == false else {
            return
        }

        if try historyRepository.fetchLatest()?.content == value {
            return
        }

        _ = try historyRepository.insert(content: value)
        try historyRepository.trimToLimit(settings.historyLimit)
        try reloadFirstPage()
    }

    func updateSearchText(_ searchText: String) throws {
        self.searchText = searchText
        try reloadFirstPage()
    }

    func loadNextPageIfNeeded(currentItem: ClipboardHistoryItem?) throws {
        guard let currentItem, currentItem.id == items.last?.id else {
            return
        }

        guard hasMorePages, isLoadingMore == false else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let page = try historyRepository.fetchPage(
            searchText: normalizedSearchText,
            limit: AppConfiguration.historyPageSize,
            offset: currentOffset
        )
        items.append(contentsOf: page.items)
        currentOffset += page.items.count
        hasMorePages = page.hasMore
        try refreshFavoriteIDs()
        storageErrorMessage = nil
    }

    func isItemFavorited(_ historyItemID: Int64) -> Bool {
        favoritedItemIDs.contains(historyItemID)
    }

    func loadFavorites() throws {
        let page = try favoritesRepository.fetchPage(limit: AppConfiguration.historyPageSize, offset: 0)
        favoriteItems = page.items
        favoriteOffset = page.items.count
        favoriteHasMorePages = page.hasMore
        storageErrorMessage = nil
    }

    func addFavorite(historyItemID: Int64) throws {
        try favoritesRepository.addFavorite(historyItemID: historyItemID)
        favoritedItemIDs.insert(historyItemID)
        try refreshLoadedFavoritesIfNeeded(force: true)
        storageErrorMessage = nil
    }

    func removeFavorite(historyItemID: Int64) throws {
        try favoritesRepository.removeFavorite(historyItemID: historyItemID)
        favoritedItemIDs.remove(historyItemID)
        favoriteItems.removeAll { $0.historyItem.id == historyItemID }
        if currentPage == .favorites {
            try refreshLoadedFavoritesIfNeeded()
        }
        storageErrorMessage = nil
    }

    func select(item: ClipboardHistoryItem) throws {
        clipboardMonitor.copyToPasteboard(item.content)
        try historyRepository.markRecopied(id: item.id)
        try reloadFirstPage()
    }

    func delete(item: ClipboardHistoryItem) throws {
        try historyRepository.delete(id: item.id)
        try favoritesRepository.removeFavorite(historyItemID: item.id)
        try reloadFirstPage()
        favoriteItems.removeAll { $0.historyItem.id == item.id }
        favoritedItemIDs.remove(item.id)
    }

    func clearAll() throws {
        try historyRepository.clearAll()
        try favoritesRepository.clearAll()
        try reloadFirstPage()
        favoriteItems = []
        favoritedItemIDs = []
    }

    func updatePauseState(_ isPaused: Bool) throws {
        let previousSettings = settings
        settings.isPaused = isPaused

        do {
            try settingsRepository.save(settings)
            storageErrorMessage = nil
        } catch {
            settings = previousSettings
            storageErrorMessage = error.localizedDescription
            throw error
        }
    }

    func updateHistoryLimit(_ historyLimit: Int) throws {
        let previousSettings = settings
        settings.historyLimit = historyLimit

        do {
            try settingsRepository.save(settings)
            try historyRepository.trimToLimit(historyLimit)
            try reloadFirstPage()
        } catch {
            settings = previousSettings
            storageErrorMessage = error.localizedDescription
            throw error
        }
    }

    private var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func refreshFavoriteIDs() throws {
        favoritedItemIDs = try favoritesRepository.fetchFavoriteIDs(for: items.map(\.id))
    }

    private func refreshLoadedFavoritesIfNeeded(force: Bool = false) throws {
        guard force || favoriteItems.isEmpty == false || currentPage == .favorites else {
            return
        }
        try loadFavorites()
    }

    private func reloadFirstPage() throws {
        let page = try historyRepository.fetchPage(
            searchText: normalizedSearchText,
            limit: AppConfiguration.historyPageSize,
            offset: 0
        )
        items = page.items
        currentOffset = page.items.count
        hasMorePages = page.hasMore
        isLoadingMore = false
        try refreshFavoriteIDs()
        storageErrorMessage = nil
    }
}
