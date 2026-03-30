import Foundation

struct ImageHistoryItem: Identifiable {
    let id: Int64
    let contentHash: String
    let capturedAt: Date
    let lastRecopiedAt: Date?
    var isStarred: Bool
}

extension ImageHistoryItem: Equatable {
    static func == (lhs: ImageHistoryItem, rhs: ImageHistoryItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.contentHash == rhs.contentHash &&
        lhs.capturedAt == rhs.capturedAt &&
        lhs.lastRecopiedAt == rhs.lastRecopiedAt &&
        lhs.isStarred == rhs.isStarred
    }
}
