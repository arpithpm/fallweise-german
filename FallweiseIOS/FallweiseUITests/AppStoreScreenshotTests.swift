import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset", "--uitesting-offline", "--uitesting-disable-animations"]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testCaptureAppStoreScreens() throws {
        capture("01-home")

        app.buttons["Learn"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Choose your chapter"].waitForExistence(timeout: 5))
        capture("02-course-path")

        app.buttons["Words"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Remember words"].waitForExistence(timeout: 5))
        app.staticTexts["Hello & goodbye"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SET 1'")).firstMatch.waitForExistence(timeout: 5))
        capture("03-vocabulary-sets")

        app.buttons["Study"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close lesson"].waitForExistence(timeout: 5))
        capture("04-visual-memory")
        app.buttons["Close lesson"].tap()

        app.buttons["Mia"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Learn with Mia"].waitForExistence(timeout: 5))
        capture("05-mia")

        app.buttons["Progress"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Progress that helps"].waitForExistence(timeout: 5))
        capture("06-progress")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
