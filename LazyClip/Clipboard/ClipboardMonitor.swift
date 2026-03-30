import Foundation

enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)
}

final class ClipboardMonitor {
    private let pasteboard: PasteboardClient
    private let pollInterval: TimeInterval
    private var lastSeenChangeCount: Int
    private var ignoredSelfWrittenChangeCount: Int?

    init(pasteboard: PasteboardClient, pollInterval: TimeInterval) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        lastSeenChangeCount = pasteboard.changeCount
    }

    func pollOnce() -> ClipboardContent? {
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount > lastSeenChangeCount else {
            return nil
        }

        lastSeenChangeCount = currentChangeCount

        if ignoredSelfWrittenChangeCount == currentChangeCount {
            ignoredSelfWrittenChangeCount = nil
            return nil
        }

        ignoredSelfWrittenChangeCount = nil

        if let value = pasteboard.readString(), value.isEmpty == false {
            return .text(value)
        }

        if let imageData = pasteboard.readImage() {
            return .image(imageData)
        }

        return nil
    }

    func copyToPasteboard(_ value: String) {
        pasteboard.writeString(value)
        ignoredSelfWrittenChangeCount = pasteboard.changeCount
    }

    func copyImageToPasteboard(_ data: Data) {
        pasteboard.writeImage(data)
        ignoredSelfWrittenChangeCount = pasteboard.changeCount
    }
}
