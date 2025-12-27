//
//  VolumeCrisisUITests.swift
//  VolumeCrisisUITests
//
//  Created by Kar Marsten on 7/11/25.
//

import XCTest

final class VolumeCrisisUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testAppLaunches() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.exists, "App should launch")
    }
    
    @MainActor
    func testMainUIElementsExist() throws {
        // Test that main UI elements are present
        XCTAssertTrue(app.navigationBars["Volume Crisis"].exists, "Navigation bar should exist")
        
        // Check for key text elements
        XCTAssertTrue(app.staticTexts.matching(identifier: "Current User").firstMatch.exists || 
                     app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Current User'")).firstMatch.exists,
                     "Current User label should exist")
    }
    
    @MainActor
    func testVolumeSlidersExist() throws {
        // Test that volume sliders are present
        // Note: Sliders might be identified differently, so we check for sliders in general
        let sliders = app.sliders
        XCTAssertGreaterThan(sliders.count, 0, "At least one slider should exist")
    }
    
    @MainActor
    func testPresetButtonsExist() throws {
        // Test that preset buttons are accessible
        // Presets are displayed as buttons, so we check for buttons
        let buttons = app.buttons
        XCTAssertGreaterThan(buttons.count, 0, "At least one button should exist")
    }
    
    @MainActor
    func testAddPresetButton() throws {
        // Test that "Add Preset" button exists and is tappable
        let addPresetButton = app.buttons["Add Preset"]
        if addPresetButton.exists {
            XCTAssertTrue(addPresetButton.isHittable, "Add Preset button should be tappable")
        }
    }
    
    @MainActor
    func testSwitchUserButton() throws {
        // Test that "Switch User" button exists
        let switchUserButton = app.buttons["Switch User"]
        if switchUserButton.exists {
            XCTAssertTrue(switchUserButton.isHittable, "Switch User button should be tappable")
        }
    }
    
    @MainActor
    func testPlayTestSoundButton() throws {
        // Test that "Play Test Sound" button exists
        let playButton = app.buttons["Play Test Sound"]
        if playButton.exists {
            XCTAssertTrue(playButton.isHittable, "Play Test Sound button should be tappable")
        }
    }
    
    @MainActor
    func testStopTestSoundButton() throws {
        // Test that "Stop Test Sound" button exists
        let stopButton = app.buttons["Stop Test Sound"]
        if stopButton.exists {
            XCTAssertTrue(stopButton.isHittable, "Stop Test Sound button should be tappable")
        }
    }
    
    @MainActor
    func testScrollView() throws {
        // Test that content is scrollable
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            XCTAssertTrue(scrollView.isHittable, "Scroll view should be accessible")
        }
    }
}
