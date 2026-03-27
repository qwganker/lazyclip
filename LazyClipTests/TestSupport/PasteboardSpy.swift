import Foundation
@testable import LazyClip

final class PasteboardSpy: PasteboardClient {
    private(set) var changeCount: Int = 0
    private(set) var lastWrittenValue: String?
    private var readValue: String?

    func setReadValue(_ value: String?, changeCount: Int) {
        readValue = value
        self.changeCount = changeCount
    }

    func readString() -> String? {
        readValue
    }

    func writeString(_ value: String) {
        lastWrittenValue = value
        readValue = value
        changeCount += 1
    }
}
