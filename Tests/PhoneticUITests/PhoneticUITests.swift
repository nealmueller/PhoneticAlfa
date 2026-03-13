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
        app.launchEnvironment["UITEST_DISABLE_SPEECH"] = "1"
        app.launch()

        XCUIDevice.shared.orientation = .portrait
        dismissInitialModeChooserIfNeeded(in: app)

        let speakTab = app.tabBars.buttons["Speak"]
        if speakTab.waitForExistence(timeout: 4) {
            speakTab.tap()
        }

        var inputEditor = app.textFields["enterTextField"]
        var outputView = app.otherElements["phoneticReadbackView"]
        var clearButton = app.buttons["clearButton"]
        var speakButton = app.buttons["speakButton"]

        if !inputEditor.waitForExistence(timeout: 5) {
            inputEditor = app.textFields.firstMatch
        }
        XCTAssertTrue(inputEditor.exists)

        if !outputView.waitForExistence(timeout: 2) {
            outputView = app.otherElements.containing(.staticText, identifier: "Phonetic readback").firstMatch
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
    func testAppStoreFeatureScreenshots() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_SPEECH"] = "1"
        app.launch()

        XCUIDevice.shared.orientation = .portrait
        dismissInitialModeChooserIfNeeded(in: app)

        func tapTab(_ title: String) {
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 4) {
                tab.tap()
            }
        }

        func tapCenter(_ element: XCUIElement) {
            let center = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
        }

        func wait(_ seconds: TimeInterval) {
            Thread.sleep(forTimeInterval: seconds)
        }

        // 1) Flashcard - front card.
        tapTab("Flashcard")
        let drillCard = app.otherElements.containing(.staticText, identifier: "Flashcard").firstMatch
        wait(0.5)
        addScreenshot(index: 1, label: "Flashcard_Front")

        // 2) Flashcard - flipped side.
        if drillCard.exists {
            tapCenter(drillCard)
            wait(0.35)
        } else {
            app.windows.firstMatch.tap()
            wait(0.35)
        }
        addScreenshot(index: 2, label: "Flashcard_Flipped")

        // 3) Flashcard - swipe interaction.
        if drillCard.exists {
            drillCard.swipeLeft()
            wait(0.4)
        }
        addScreenshot(index: 3, label: "Flashcard_Swipe")

        // 4) Quiz - visual with large choices.
        tapTab("Quiz")
        let startQuiz = app.buttons["Start Quiz"]
        if startQuiz.waitForExistence(timeout: 3) {
            startQuiz.tap()
            wait(0.5)
        }
        addScreenshot(index: 4, label: "Quiz_Visual")

        // 5) Quiz - audio mode from a clean launch so mode picker is visible.
        app.terminate()
        app.launch()
        dismissInitialModeChooserIfNeeded(in: app)
        tapTab("Quiz")
        let modePicker = app.segmentedControls.firstMatch
        if modePicker.waitForExistence(timeout: 2) {
            let audioSegment = modePicker.buttons["Audio"]
            if audioSegment.exists {
                audioSegment.tap()
                wait(0.2)
            }
        }
        if startQuiz.waitForExistence(timeout: 2) {
            startQuiz.tap()
            wait(0.5)
        }
        addScreenshot(index: 5, label: "Quiz_Audio")

        // 6) Speak tab.
        tapTab("Speak")
        let enterField = app.textFields["enterTextField"]
        if enterField.waitForExistence(timeout: 3) {
            enterField.tap()
            enterField.typeText("AB 12")
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            }
            wait(0.3)
        }
        addScreenshot(index: 6, label: "Speak")

        // 7) Settings - alphabet and monetization options.
        tapTab("Settings")
        wait(0.4)
        addScreenshot(index: 7, label: "Settings")

        // 8) Quiz home card (clean, no modal risk).
        tapTab("Quiz")
        wait(0.4)
        addScreenshot(index: 8, label: "Quiz_Home")
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

    @MainActor
    func testPremiumOverrideHidesAds() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_SPEECH"] = "1"
        app.launchEnvironment["UITEST_FORCE_AD_FREE"] = "1"
        app.launch()

        dismissInitialModeChooserIfNeeded(in: app)

        XCTAssertFalse(app.otherElements["adBannerContainer"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFreeModeShowsAdContainer() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_SPEECH"] = "1"
        app.launch()

        dismissInitialModeChooserIfNeeded(in: app)

        XCTAssertTrue(app.otherElements["adBannerContainer"].waitForExistence(timeout: 2))
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

@MainActor
private func dismissInitialModeChooserIfNeeded(in app: XCUIApplication) {
    let chooserTitle = app.staticTexts["Choose Your Alphabet"]
    guard chooserTitle.waitForExistence(timeout: 1.5) else { return }

    let natoButton = app.buttons["NATO"]
    if natoButton.waitForExistence(timeout: 2) {
        natoButton.tap()
        return
    }

    let buttonCandidate = app.buttons.containing(.staticText, identifier: "NATO").firstMatch
    if buttonCandidate.waitForExistence(timeout: 2) {
        buttonCandidate.tap()
    }
}
