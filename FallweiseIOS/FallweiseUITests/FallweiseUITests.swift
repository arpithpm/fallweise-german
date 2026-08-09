import XCTest

final class FallweiseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset", "--uitesting-offline", "--uitesting-disable-animations"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 8))
    }

    func testAllPrimaryTabsAndLevelSwitching() {
        XCTAssertTrue(app.staticTexts["Ready for one win?"].exists)

        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["Choose your chapter"].waitForExistence(timeout: 3))
        app.buttons["A2 Everyday German"].tap()
        XCTAssertTrue(app.staticTexts["A2 · 12 chapters"].waitForExistence(timeout: 3))
        app.buttons["B1 Independence"].tap()
        XCTAssertTrue(app.staticTexts["B1 · 12 chapters"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.staticTexts["Remember words"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.searchFields["German or English word"].exists)

        app.tabBars.buttons["Mia"].tap()
        XCTAssertTrue(app.staticTexts["Learn with Mia"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Progress that helps"].waitForExistence(timeout: 3))
    }

    func testAdaptivePracticeAnswerAndRatingFlow() {
        app.buttons["Start adaptive practice"].tap()
        XCTAssertTrue(app.staticTexts["Recall before you reveal"].waitForExistence(timeout: 3))

        let field = app.textFields["Type your answer"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText("Hallo!")
        app.buttons["Check"].tap()
        XCTAssertTrue(app.staticTexts["Retrieved"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Hard"].exists)
        XCTAssertTrue(app.buttons["Good"].exists)
        XCTAssertTrue(app.buttons["Easy"].exists)
        app.buttons["Good"].tap()
        XCTAssertTrue(app.staticTexts["MEMORY"].exists || app.staticTexts["Recall before you reveal"].exists)
        app.buttons["Close lesson"].tap()
        XCTAssertTrue(app.staticTexts["Ready for one win?"].waitForExistence(timeout: 3))
    }

    func testSelfStudyRecallFlowAndClose() {
        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["Meet & greet"].waitForExistence(timeout: 3))
        app.buttons["Study"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Meet & greet"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()
        let field = app.textFields["Retrieve the German first"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText("ich heisse mia")
        app.buttons["Check"].tap()
        XCTAssertTrue(app.buttons["I knew it"].waitForExistence(timeout: 3))
        app.buttons["I knew it"].tap()
        XCTAssertTrue(app.staticTexts["Wie heißt du?"].waitForExistence(timeout: 1))
        let secondField = app.textFields["Retrieve the German first"]
        secondField.tap(); secondField.typeText("ich heisse arpith")
        app.buttons["Check"].tap()
        app.buttons["I knew it"].tap()
        XCTAssertTrue(app.staticTexts["LESSON COMPLETE"].waitForExistence(timeout: 1))
        app.buttons["Close lesson"].tap()
        XCTAssertTrue(app.staticTexts["Choose your chapter"].waitForExistence(timeout: 3))
    }

    func testWordsSearchExpansionAndLessonEntry() {
        app.tabBars.buttons["Words"].tap()
        let search = app.searchFields["German or English word"]
        search.tap(); search.typeText("goodbye")
        XCTAssertTrue(app.staticTexts["Hello & goodbye"].waitForExistence(timeout: 3))
        app.staticTexts["Hello & goodbye"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SET 1'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Study"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close lesson"].waitForExistence(timeout: 3))
        app.buttons["Close lesson"].tap()
    }

    func testMiaAndRolePlayEntryScreensWithoutConnecting() {
        app.tabBars.buttons["Mia"].tap()
        app.buttons["Practice hands-free with Mia"].tap()
        XCTAssertTrue(app.buttons["Continue with Mia"].waitForExistence(timeout: 3))
        app.buttons["Close lesson"].tap()

        app.staticTexts["Order at a café"].tap()
        XCTAssertTrue(app.staticTexts["Mia stays in character"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Enter the scene"].exists)
        app.buttons["Close lesson"].tap()
    }

    func testProgressGoalsAndWeeklyGoal() {
        app.tabBars.buttons["Progress"].tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.staticTexts["Make German relevant"].waitForExistence(timeout: 3))
        app.buttons["Travel"].tap()
        XCTAssertTrue(app.switches["Gentle daily review reminder"].exists)
        XCTAssertTrue(app.staticTexts["Delayed recall"].exists)
    }

    func testCoreNavigationWithAccessibilityTextAndLandscape() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["Choose your chapter"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.searchFields["German or English word"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Mia"].tap()
        XCTAssertTrue(app.staticTexts["Learn with Mia"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Progress that helps"].waitForExistence(timeout: 4))
    }
}
