import Foundation

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

    func pollOnce() -> String? {
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

        guard let value = pasteboard.readString(), value.isEmpty == false else {
            return nil
        }

        return value
    }

    func copyToPasteboard(_ value: String) {
        pasteboard.writeString(value)
        ignoredSelfWrittenChangeCount = pasteboard.changeCount
    }
}
