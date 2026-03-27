import XCTest
@testable import LazyClip

final class ClipboardMonitorTests: XCTestCase {
    func testPollDoesNotEmitPreExistingClipboardContentsOnFirstPollAfterInitialization() throws {
        let pasteboard = PasteboardSpy()
        pasteboard.setReadValue("existing", changeCount: 1)

        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        XCTAssertNil(monitor.pollOnce())
    }

    func testPollReturnsStringWhenChangeCountAdvances() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        pasteboard.setReadValue("hello", changeCount: 1)

        let value = monitor.pollOnce()

        XCTAssertEqual(value, "hello")
    }

    func testPollSkipsSelfWrittenClipboardValue() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        monitor.copyToPasteboard("self write")

        XCTAssertNil(monitor.pollOnce())
    }

    func testPollAcceptsExternalCopyOfSameStringIfClipboardChangedAgainAfterSelfWrite() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        monitor.copyToPasteboard("repeat value")
        pasteboard.setReadValue("repeat value", changeCount: 2)

        XCTAssertEqual(monitor.pollOnce(), "repeat value")
    }

    func testPollAcceptsLaterExternalCopyOfSameStringAfterSelfWriteIsConsumed() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        monitor.copyToPasteboard("repeat value")
        XCTAssertNil(monitor.pollOnce())

        pasteboard.setReadValue("repeat value", changeCount: 2)

        XCTAssertEqual(monitor.pollOnce(), "repeat value")
    }

    func testPollIgnoresEmptyClipboardStrings() throws {
        let pasteboard = PasteboardSpy()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 0.5)

        pasteboard.setReadValue("", changeCount: 1)

        XCTAssertNil(monitor.pollOnce())
    }
}
