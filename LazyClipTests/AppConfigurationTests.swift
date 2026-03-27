import XCTest
@testable import LazyClip

final class AppConfigurationTests: XCTestCase {
    func testDefaultsMatchSpec() {
        XCTAssertEqual(AppConfiguration.defaultHistoryLimit, 500)
        XCTAssertEqual(AppConfiguration.historyPageSize, 100)
        XCTAssertEqual(AppConfiguration.pasteboardPollInterval, 0.5)
        XCTAssertEqual(AppConfiguration.listScrollbarReservedWidth, 4)
    }

    func testSettingsVersionTextUsesMarketingVersionOnly() {
        let versionText = SettingsView.versionText(from: [
            "CFBundleShortVersionString": "0.1.1",
            "CFBundleVersion": "42"
        ])

        XCTAssertEqual(versionText, "Version 0.1.1")
    }

    func testSettingsFormRowTitlesPlaceVersionBeforePauseRecording() {
        let titles = SettingsView.formRowTitles(versionText: "Version 0.1.1")

        XCTAssertEqual(titles.prefix(2), ["Version 0.1.1", "Pause recording"])
    }
}
