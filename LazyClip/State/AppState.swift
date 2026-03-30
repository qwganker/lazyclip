import CryptoKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    enum Page {
        case history
        case favorites
        case settings
    }

    enum ContentType {
        case text, images
    }

    @Published var settings: AppSettings
    @Published var searchText: String
    @Published var items: [ClipboardHistoryItem]
    @Published var favoriteItems: [FavoriteHistoryItem]
    @Published var currentPage: Page
    @Published var isLoadingMore: Bool
    @Published var isLoadingMoreFavorites: Bool
    @Published var imageItems: [ImageHistoryItem]
    @Published var isLoadingMoreImages: Bool
    @Published var starredImageItems: [ImageHistoryItem]
    @Published var isLoadingMoreStarredImages: Bool
    @Published var storageErrorMessage: String?

    private let settingsRepository: SettingsRepository
    private let historyRepository: HistoryRepository
    private let favoritesRepository: FavoritesRepository
    private let imageRepository: ImageRepository
    private let clipboardMonitor: ClipboardMonitor
    private(set) var favoritedItemIDs: Set<Int64>
    private var currentOffset: Int
    private var hasMorePages: Bool
    private var favoriteOffset: Int
    private var favoriteHasMorePages: Bool
    private var imageOffset: Int
    private var imageHasMorePages: Bool
    private var starredImageOffset: Int
    private var starredImageHasMorePages: Bool
    @Published var historyContentTab: ContentType = .text
    @Published var favoritesContentTab: ContentType = .text

    init(
        settingsRepository: SettingsRepository,
        historyRepository: HistoryRepository,
        favoritesRepository: FavoritesRepository,
        imageRepository: ImageRepository,
        clipboardMonitor: ClipboardMonitor
    ) {
        self.settingsRepository = settingsRepository
        self.historyRepository = historyRepository
        self.favoritesRepository = favoritesRepository
        self.imageRepository = imageRepository
        self.clipboardMonitor = clipboardMonitor
        settings = AppSettings(isPaused: false, historyLimit: AppConfiguration.defaultHistoryLimit, imageSizeLimitMB: AppConfiguration.defaultImageSizeLimitMB)
        searchText = ""
        items = []
        favoriteItems = []
        imageItems = []
        starredImageItems = []
        currentPage = .history
        isLoadingMore = false
        isLoadingMoreFavorites = false
        isLoadingMoreImages = false
        isLoadingMoreStarredImages = false
        storageErrorMessage = nil
        favoritedItemIDs = []
        currentOffset = 0
        hasMorePages = false
        favoriteOffset = 0
        favoriteHasMorePages = false
        imageOffset = 0
        imageHasMorePages = false
        starredImageOffset = 0
        starredImageHasMorePages = false
    }

    func loadInitialData() throws {
        settings = try settingsRepository.load()
        try reloadFirstPage()
        try loadFavorites()
        try reloadImageFirstPage()
    }

    func handleClipboardPoll() throws {
        guard let content = clipboardMonitor.pollOnce() else {
            return
        }

        guard settings.isPaused == false else {
            return
        }

        switch content {
        case .text(let value):
            if try historyRepository.fetchLatest()?.content == value {
                return
            }
            _ = try historyRepository.insert(content: value)
            try historyRepository.trimToLimit(settings.historyLimit)
            try reloadFirstPage()
            try refreshLoadedFavoritesIfNeeded()

        case .image(let data):
            let limitBytes = settings.imageSizeLimitMB * 1024 * 1024
            guard data.count <= limitBytes else { return }
            let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            if try imageRepository.fetchLatest()?.contentHash == hash { return }
            _ = try imageRepository.insert(imageData: data)
            try imageRepository.trimToLimit(settings.historyLimit)
            try reloadImageFirstPage()
        }
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
        try imageRepository.deleteAll()
        ThumbnailCache.shared.removeAll()
        try reloadFirstPage()
        favoriteItems = []
        favoritedItemIDs = []
        imageItems = []
        starredImageItems = []
        imageOffset = 0
        imageHasMorePages = false
        starredImageOffset = 0
        starredImageHasMorePages = false
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

    // MARK: - Image actions

    func loadNextImagePageIfNeeded(currentItem: ImageHistoryItem) {
        guard currentItem.id == imageItems.last?.id else { return }
        guard imageHasMorePages, !isLoadingMoreImages else { return }
        isLoadingMoreImages = true
        do {
            let page = try imageRepository.fetchPage(limit: AppConfiguration.imagePageSize, offset: imageOffset)
            imageItems.append(contentsOf: page.items)
            imageOffset += page.items.count
            imageHasMorePages = page.hasMore
        } catch {
            storageErrorMessage = error.localizedDescription
        }
        isLoadingMoreImages = false
    }

    func loadNextStarredImagePageIfNeeded(currentItem: ImageHistoryItem) {
        guard currentItem.id == starredImageItems.last?.id else { return }
        guard starredImageHasMorePages, !isLoadingMoreStarredImages else { return }
        isLoadingMoreStarredImages = true
        do {
            let page = try imageRepository.fetchStarredPage(limit: AppConfiguration.imagePageSize, offset: starredImageOffset)
            starredImageItems.append(contentsOf: page.items)
            starredImageOffset += page.items.count
            starredImageHasMorePages = page.hasMore
        } catch {
            storageErrorMessage = error.localizedDescription
        }
        isLoadingMoreStarredImages = false
    }

    func fetchImageData(id: Int64) throws -> Data? {
        try imageRepository.fetchImageData(id: id)
    }

    func selectImage(item: ImageHistoryItem) throws {
        guard let data = try imageRepository.fetchImageData(id: item.id) else { return }
        clipboardMonitor.copyImageToPasteboard(data)
        try imageRepository.markRecopied(id: item.id)
    }

    func deleteImage(item: ImageHistoryItem) throws {
        try imageRepository.removeStar(id: item.id)
        try imageRepository.delete(id: item.id)
        imageItems.removeAll { $0.id == item.id }
        starredImageItems.removeAll { $0.id == item.id }
    }

    func toggleImageStar(item: ImageHistoryItem) throws {
        if item.isStarred {
            try imageRepository.removeStar(id: item.id)
            if let idx = imageItems.firstIndex(where: { $0.id == item.id }) {
                imageItems[idx].isStarred = false
            }
            starredImageItems.removeAll { $0.id == item.id }
        } else {
            try imageRepository.addStar(id: item.id)
            if let idx = imageItems.firstIndex(where: { $0.id == item.id }) {
                imageItems[idx].isStarred = true
            }
            var starred = item
            starred.isStarred = true
            starredImageItems.insert(starred, at: 0)
        }
    }

    func updateImageSizeLimit(_ mb: Int) throws {
        let previousSettings = settings
        settings.imageSizeLimitMB = mb
        do {
            try settingsRepository.save(settings)
        } catch {
            settings = previousSettings
            storageErrorMessage = error.localizedDescription
            throw error
        }
    }

    func switchHistoryContentTab(_ tab: ContentType) throws {
        historyContentTab = tab
        if tab == .images {
            try reloadImageFirstPage()
        }
    }

    func switchFavoritesContentTab(_ tab: ContentType) throws {
        favoritesContentTab = tab
        if tab == .images {
            try reloadStarredImageFirstPage()
        }
    }

    private func reloadImageFirstPage() throws {
        let page = try imageRepository.fetchPage(limit: AppConfiguration.imagePageSize, offset: 0)
        imageItems = page.items
        imageOffset = page.items.count
        imageHasMorePages = page.hasMore
        isLoadingMoreImages = false
    }

    private func reloadStarredImageFirstPage() throws {
        let page = try imageRepository.fetchStarredPage(limit: AppConfiguration.imagePageSize, offset: 0)
        starredImageItems = page.items
        starredImageOffset = page.items.count
        starredImageHasMorePages = page.hasMore
        isLoadingMoreStarredImages = false
    }
}
