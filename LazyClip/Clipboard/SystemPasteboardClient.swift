import AppKit

final class SystemPasteboardClient: PasteboardClient {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    func writeString(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
