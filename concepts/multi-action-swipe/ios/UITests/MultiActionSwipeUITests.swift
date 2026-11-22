import XCTest

final class MultiActionSwipeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTryDemoOpensRealActionTray() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-multiActionSwipe.coachMarkDismissed.v2", "NO"]
        app.launch()

        let tryDemo = app.buttons["Try Demo"]
        XCTAssertTrue(tryDemo.waitForExistence(timeout: 5), "Try Demo must be visible on first launch")
        tryDemo.tap()

        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Mute"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "try-demo-open-action-tray"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
