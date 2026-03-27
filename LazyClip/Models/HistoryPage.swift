import Foundation

struct HistoryPage: Equatable {
    let items: [ClipboardHistoryItem]
    let offset: Int
    let limit: Int
    let hasMore: Bool
}
