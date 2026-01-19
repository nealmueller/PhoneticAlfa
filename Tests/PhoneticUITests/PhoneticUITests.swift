//
//  PhoneticUITests.swift
//  PhoneticUITests
//
//  Created by Neal Mueller on 1/8/26.
//

import XCTest

final class PhoneticUITests: XCTestCase {
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
        addScreenshot(index: 1, label: "Instant_NATO")

        replaceInput(with: "A-B")
        outputView.tap()
        _ = app.staticTexts["Copied"].waitForExistence(timeout: 1)
        addScreenshot(index: 2, label: "Tap_To_Copy")

        replaceInput(with: "AB 12")
        if !speakButton.exists {
            speakButton = app.buttons["Speak"]
        }
        speakButton.tap()
        addScreenshot(index: 3, label: "Speak_Stop")
        let stopButton = app.buttons["Stop"]
        if stopButton.exists {
            stopButton.tap()
        }

        replaceInput(with: "A/B")
        addScreenshot(index: 4, label: "Symbol_Handling")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil {
            throw XCTSkip("Launch performance metrics are not supported on physical devices.")
        }
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

@MainActor
private func addScreenshot(index: Int, label: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "\(index)_\(label)"
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Screenshot: \(index)_\(label)") { activity in
        activity.add(attachment)
    }

    let deviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?
        .replacingOccurrences(of: " ", with: "_") ?? "UnknownDevice"
    let defaultDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PhoneticScreenshots")
        .appendingPathComponent(deviceName)
    let baseDirPath = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] ?? defaultDir.path
    let filenamePrefix = ProcessInfo.processInfo.environment["SCREENSHOT_FILENAME_PREFIX"] ?? ""
    let fileManager = FileManager.default

    guard (try? fileManager.createDirectory(atPath: baseDirPath, withIntermediateDirectories: true)) != nil else {
        return
    }

    let fileName = String(format: "%@%02d.png", filenamePrefix, index)
    let filePath = (baseDirPath as NSString).appendingPathComponent(fileName)
    try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: filePath))
}
