//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
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

    @MainActor
    func testOpenAboutWindowShowsDetailedSections() throws {
        let app = XCUIApplication()
        app.launch()

        let showAboutButton = app.buttons["Show Full About"].firstMatch
        XCTAssertTrue(showAboutButton.waitForExistence(timeout: 5))
        showAboutButton.tap()

        XCTAssertTrue(app.staticTexts["Ringkasan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Target & Lokasi Scan"].exists)
    }
}
