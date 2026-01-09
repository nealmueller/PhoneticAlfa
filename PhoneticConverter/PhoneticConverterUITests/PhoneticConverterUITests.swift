//
//  PhoneticConverterUITests.swift
//  PhoneticConverterUITests
//
//  Created by Neal Mueller on 1/8/26.
//

import XCTest

final class PhoneticConverterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        XCUIDevice.shared.orientation = .portrait

        var inputEditor = app.textViews["inputEditor"]
        var outputView = app.otherElements["outputView"]
        var clearButton = app.buttons["clearButton"]
        var speakButton = app.buttons["speakButton"]

        if !inputEditor.waitForExistence(timeout: 5) {
            inputEditor = app.textViews.firstMatch
        }
        XCTAssertTrue(inputEditor.exists)

        if !outputView.waitForExistence(timeout: 2) {
            outputView = app.otherElements.containing(.staticText, identifier: "Output").firstMatch
        }
        if !outputView.exists {
            outputView = app.otherElements.firstMatch
        }
        XCTAssertTrue(outputView.exists)

        if !clearButton.exists {
            clearButton = app.buttons["Clear"]
        }

        func replaceInput(with text: String) {
            if clearButton.waitForExistence(timeout: 1) {
                clearButton.tap()
            } else {
                inputEditor.tap()
                inputEditor.press(forDuration: 1.0)
                if app.menuItems["Select All"].waitForExistence(timeout: 1) {
                    app.menuItems["Select All"].tap()
                }
                if app.keys["delete"].exists {
                    app.keys["delete"].tap()
                }
            }
            inputEditor.tap()
            inputEditor.typeText(text)
            outputView.tap()
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            }
        }

        replaceInput(with: "YX623K73J3")
        addScreenshot(named: "01_Instant_NATO")

        replaceInput(with: "A-B")
        outputView.tap()
        _ = app.staticTexts["Copied"].waitForExistence(timeout: 1)
        addScreenshot(named: "02_Tap_To_Copy")

        replaceInput(with: "AB 12")
        if !speakButton.exists {
            speakButton = app.buttons["Speak"]
        }
        speakButton.tap()
        addScreenshot(named: "03_Speak_Stop")
        let stopButton = app.buttons["Stop"]
        if stopButton.exists {
            stopButton.tap()
        }

        replaceInput(with: "A/B")
        addScreenshot(named: "04_Symbol_Handling")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

@MainActor
private func addScreenshot(named name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
        activity.add(attachment)
    }

    let deviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?
        .replacingOccurrences(of: " ", with: "_") ?? "UnknownDevice"
    let baseDir = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] ??
        "/Users/nealmueller/dev/PhoneticConverter/screenshots/appstore_\(deviceName)"
    let fileManager = FileManager.default
    do {
        try fileManager.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        let sanitizedName = name.replacingOccurrences(of: " ", with: "_")
        let filePath = (baseDir as NSString).appendingPathComponent("\(sanitizedName).png")
        try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: filePath))
    } catch {
        XCTFail("Failed to write screenshot: \(error)")
    }
}
