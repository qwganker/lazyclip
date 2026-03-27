import Foundation

struct ApplicationSupportPaths {
    let directoryURL: URL
    let databaseURL: URL

    init(fileManager: FileManager = .default, bundle: Bundle = .main) throws {
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folderName = bundle.bundleIdentifier ?? "LazyClip"
        directoryURL = applicationSupportDirectory.appendingPathComponent(folderName, isDirectory: true)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        databaseURL = directoryURL.appendingPathComponent("history.sqlite", isDirectory: false)
    }
}
