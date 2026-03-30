import CoreGraphics
import Foundation

enum AppConfiguration {
    static let defaultHistoryLimit = 500
    static let historyPageSize = 100
    static let pasteboardPollInterval: TimeInterval = 0.5
    static let listScrollbarReservedWidth: CGFloat = 2
    static let defaultImageSizeLimitMB = 10
    static let imagePageSize = 50
}
