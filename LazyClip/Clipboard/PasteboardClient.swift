protocol PasteboardClient {
    var changeCount: Int { get }
    func readString() -> String?
    func writeString(_ value: String)
}
