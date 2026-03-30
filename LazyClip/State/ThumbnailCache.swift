import AppKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSNumber, NSImage>()

    private init() {
        cache.countLimit = 200
    }

    func thumbnail(for id: Int64) -> NSImage? {
        cache.object(forKey: NSNumber(value: id))
    }

    func store(_ image: NSImage, for id: Int64) {
        cache.setObject(image, forKey: NSNumber(value: id))
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
