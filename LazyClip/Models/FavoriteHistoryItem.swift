import Foundation

struct FavoriteHistoryItem: Identifiable, Equatable {
    let historyItem: ClipboardHistoryItem
    let favoritedAt: Date

    var id: Int64 { historyItem.id }
}
