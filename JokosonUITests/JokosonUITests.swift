//
//  JokosonUITests.swift
//  JokosonUITests
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import XCTest

final class JokosonUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPasteAndViewJSON() throws {
        let app = XCUIApplication()
        app.launch()

        let input = app.textViews["jsonInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("{\"hello\":\"world\"}")

        let viewButton = app.buttons["viewJSONButton"]
        XCTAssertTrue(viewButton.waitForExistence(timeout: 2))
        viewButton.tap()

        XCTAssertTrue(app.otherElements["jsonViewer"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testInvalidJSONShowsInlineError() throws {
        let app = XCUIApplication()
        app.launch()

        let input = app.textViews["jsonInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("{\"broken\":}")
        app.buttons["viewJSONButton"].tap()

        XCTAssertTrue(app.otherElements["parseError"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
