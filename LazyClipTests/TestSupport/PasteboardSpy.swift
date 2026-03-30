import Foundation
@testable import LazyClip

final class PasteboardSpy: PasteboardClient {
    private(set) var changeCount: Int = 0
    private(set) var lastWrittenValue: String?
    private(set) var lastWrittenImageData: Data?
    private var readValue: String?
    private var readImageValue: Data?

    func setReadValue(_ value: String?, changeCount: Int) {
        readValue = value
        self.changeCount = changeCount
    }

    func setReadImageValue(_ data: Data?, changeCount: Int) {
        readImageValue = data
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

    func readImage() -> Data? {
        readImageValue
    }

    func writeImage(_ data: Data) {
        lastWrittenImageData = data
        readImageValue = data
        changeCount += 1
    }
}
