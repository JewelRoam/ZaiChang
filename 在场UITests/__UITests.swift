//
//  __UITests.swift
//  在场UITests
//
//  Created by 郑恩嵘 on 2026/8/10.
//

import XCTest

final class __UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSceneSelectionRefreshesBackground() throws {
        let app = launchApp()

        XCTAssertTrue(app.images["专注状态的雨夜书房静态背景"].waitForExistence(timeout: 3))
        app.buttons["场景"].click()
        app.buttons["选择场景：创作"].click()

        XCTAssertTrue(app.images["创作状态的暖光工作坊静态背景"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.images["专注状态的雨夜书房静态背景"].exists)
    }

    @MainActor
    func testJoinConfigureAndStartFocus() throws {
        let app = launchApp()

        app.buttons["同桌"].click()
        let inviteCode = app.textFields["输入任意邀请码"]
        XCTAssertTrue(inviteCode.waitForExistence(timeout: 3))
        inviteCode.click()
        inviteCode.typeText("demo")
        app.buttons["加入房间"].click()

        XCTAssertTrue(app.staticTexts["准备这一段专注"].waitForExistence(timeout: 3))
        app.buttons["选择 Todo：补齐方案最后两页"].click()
        app.buttons["开始这一段专注"].click()

        XCTAssertTrue(app.buttons["结束专注"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["重置计时器"].isEnabled)
    }

    @MainActor
    func testManuallyEndFocusOpensRecorderGuide() throws {
        let app = launchApp()
        startFocus(in: app)

        app.buttons["结束专注"].click()
        let confirmEnd = app.sheets.buttons["确认结束专注"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 2))
        confirmEnd.click()

        XCTAssertTrue(app.buttons["打开留声机"].waitForExistence(timeout: 3))
        app.buttons["打开留声机"].click()
        XCTAssertTrue(app.staticTexts["把这句话留到合适的时候"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["同桌"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func startFocus(in app: XCUIApplication) {
        app.buttons["同桌"].click()
        let inviteCode = app.textFields["输入任意邀请码"]
        XCTAssertTrue(inviteCode.waitForExistence(timeout: 3))
        inviteCode.click()
        inviteCode.typeText("demo")
        app.buttons["加入房间"].click()
        XCTAssertTrue(app.staticTexts["准备这一段专注"].waitForExistence(timeout: 3))
        app.buttons["选择 Todo：补齐方案最后两页"].click()
        app.buttons["开始这一段专注"].click()
        XCTAssertTrue(app.buttons["结束专注"].waitForExistence(timeout: 3))
    }
}
