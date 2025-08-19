//
//  xTUITestsLaunchTests.swift
//  xTUITests
//
//  Created by Starla Cortes on 5/16/25.
//

import XCTest

final class xTUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "xTLaunchScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
