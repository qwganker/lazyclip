import Foundation

struct ImageHistoryItem: Identifiable, Equatable {
    let id: Int64
    let imageData: Data
    let contentHash: String
    let capturedAt: Date
    let lastRecopiedAt: Date?
    var isStarred: Bool
}
