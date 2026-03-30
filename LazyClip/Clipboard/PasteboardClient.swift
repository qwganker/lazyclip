import Foundation

protocol PasteboardClient {
    var changeCount: Int { get }
    func readString() -> String?
    func writeString(_ value: String)
    func readImage() -> Data?
    func writeImage(_ data: Data)
}
