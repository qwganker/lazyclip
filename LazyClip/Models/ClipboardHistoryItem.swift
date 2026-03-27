import Foundation

struct ClipboardHistoryItem: Identifiable, Equatable {
    let id: Int64
    let content: String
    let contentHash: String
    let capturedAt: Date
    let lastRecopiedAt: Date?
}
