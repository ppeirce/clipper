import XCTest

final class ClipperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFixtureAllowsClipDeletion() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let clipCount = app.descendants(matching: .any)["clip-count"]
        XCTAssertTrue(clipCount.waitForExistence(timeout: 2))
        XCTAssertEqual(displayedText(of: clipCount), "2 clips")

        app.buttons["clip-chip-1"].click()
        let deleteButton = app.buttons["delete-selected-clip"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        XCTAssertTrue(deleteButton.isEnabled)
        deleteButton.click()
        XCTAssertEqual(displayedText(of: clipCount), "1 clip")
    }

    @MainActor
    func testFixtureShowsOverlapErrorWhenEditingWouldCollide() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        app.buttons["clip-chip-1"].click()
        app.buttons["clip-chip-2"].click()
        let setSelectedStartButton = app.buttons["set-selected-start-to-playhead"]
        XCTAssertTrue(setSelectedStartButton.waitForExistence(timeout: 2))
        setSelectedStartButton.click()

        XCTAssertEqual(displayedText(of: app.staticTexts["status-message"]), "Clips cannot overlap existing ranges.")
    }

    @MainActor
    private func displayedText(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        return element.label
    }

}
