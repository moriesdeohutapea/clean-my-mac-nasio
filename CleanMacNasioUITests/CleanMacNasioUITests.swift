//
//  CleanMacNasioUITests.swift
//  CleanMacNasioUITests
//
//  Created by Mories Hutapea on 19/07/25.
//

import XCTest

final class CleanMacNasioUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardLaunchesWithPrimaryActions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CleanMacNasio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scan"].exists)
    }
}
