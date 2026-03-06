import XCTest
@testable import ClipperKit

final class KeyboardShortcutInterpreterTests: XCTestCase {
    func testMapsTransportShortcuts() {
        XCTAssertEqual(
            KeyboardShortcutInterpreter.command(for: KeyboardInput(keyCode: 49, characters: " ", isShiftPressed: false)),
            .togglePlayback
        )
        XCTAssertEqual(
            KeyboardShortcutInterpreter.command(for: KeyboardInput(keyCode: 123, characters: "", isShiftPressed: false)),
            .seekBackwardFiveSeconds
        )
        XCTAssertEqual(
            KeyboardShortcutInterpreter.command(for: KeyboardInput(keyCode: 124, characters: "", isShiftPressed: true)),
            .stepForwardFrame
        )
    }

    func testMapsClipMarkers() {
        XCTAssertEqual(
            KeyboardShortcutInterpreter.command(for: KeyboardInput(keyCode: 34, characters: "i", isShiftPressed: false)),
            .markIn
        )
        XCTAssertEqual(
            KeyboardShortcutInterpreter.command(for: KeyboardInput(keyCode: 31, characters: "O", isShiftPressed: false)),
            .markOut
        )
    }
}
