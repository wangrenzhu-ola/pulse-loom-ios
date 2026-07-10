import XCTest

final class PulseLoomUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-practice-state", "--reset-purchase-state"]
        app.launch()
    }

    func testQuickWeaveReachesTimingReviewAndWeakReplay() {
        let start = app.buttons["start-quick-weave"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.staticTexts["Get ready"].waitForExistence(timeout: 3))
        let tapSurface = app.buttons["practice-tap-surface"]
        XCTAssertTrue(tapSurface.waitForExistence(timeout: 8))
        for _ in 0..<8 { tapSurface.tap() }
        tapSurface.tap()

        XCTAssertTrue(app.staticTexts["Timing review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["replay-weak-cells"].exists)
        XCTAssertTrue(app.staticTexts["Saved locally"].exists)
    }

    func testCreateAndDeleteCustomPatternThroughReachableUI() {
        app.tabBars.buttons["Patterns"].tap()
        let create = app.buttons["create-first-pattern"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        XCTAssertTrue(app.navigationBars["New Pattern"].waitForExistence(timeout: 3))
        app.buttons["save-pattern"].tap()
        let patternName = app.staticTexts["Offbeat Warm-up"]
        XCTAssertTrue(patternName.waitForExistence(timeout: 5))
        patternName.tap()

        XCTAssertTrue(app.buttons["Edit pattern"].waitForExistence(timeout: 3))
        app.buttons["Delete pattern"].tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 2))
        app.alerts.buttons["Delete"].tap()

        XCTAssertFalse(app.staticTexts["Offbeat Warm-up"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["create-first-pattern"].exists)
    }

    func testPrivacyScreenStatesLocalOnlyBoundary() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Local-only practice data"].tap()

        XCTAssertTrue(app.staticTexts["Your practice stays here."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What Pulse Loom does not use"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No microphone'")).firstMatch.exists)
    }

    func testStoreUnavailableShowsRecoveryWithoutBlockingFreeCore() {
        app.terminate()
        app.launchArguments.append("--force-store-unavailable")
        app.launch()

        app.buttons["Explore Full Practice Library"].tap()
        XCTAssertTrue(app.staticTexts["Full Practice Library"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Purchases are temporarily unavailable"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Restore purchases"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'stay free forever'")).firstMatch.exists)
    }
}
