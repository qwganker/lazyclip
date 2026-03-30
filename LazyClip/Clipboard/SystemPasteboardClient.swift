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

    func readImage() -> Data? {
        if let tiffData = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiffData) {
            return rep.representation(using: .png, properties: [:])
        }
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }
        return nil
    }

    func writeImage(_ data: Data) {
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}
