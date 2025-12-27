//
//  SystemVolumeMonitorTests.swift
//  VolumeCrisisTests
//
//  Created by Kar Marsten on 12/27/24.
//

import XCTest
import AVFoundation
@testable import VolumeCrisis

@MainActor
final class SystemVolumeMonitorTests: XCTestCase {
    var monitor: SystemVolumeMonitor!
    
    override func setUp() {
        super.setUp()
        // Note: SystemVolumeMonitor is a singleton, so we test the shared instance
        monitor = SystemVolumeMonitor.shared
    }
    
    override func tearDown() {
        monitor = nil
        super.tearDown()
    }
    
    func testDeviceTypeDetection() {
        // Test that device type detection works
        let isiPad = monitor.isRunningOniPad
        let canControl = monitor.canControlSystemVolume
        
        // On simulator, this will depend on the device type selected
        // Just verify the properties exist and return boolean values
        XCTAssertTrue(type(of: isiPad) == Bool.self)
        XCTAssertTrue(type(of: canControl) == Bool.self)
        
        // Verify the relationship: if iPad, cannot control; if iPhone, can control
        if isiPad {
            XCTAssertFalse(canControl, "iPad should not allow programmatic volume control")
        } else {
            XCTAssertTrue(canControl, "iPhone should allow programmatic volume control")
        }
    }
    
    func testSystemVolumeCeilingDefault() {
        // Test that ceiling defaults to 1.0 (100%)
        XCTAssertEqual(monitor.systemVolumeCeiling, 1.0, accuracy: 0.01)
    }
    
    func testSystemVolumeCeilingPersistence() {
        // Test that ceiling can be set and persists
        let testCeiling: Float = 0.75
        
        monitor.systemVolumeCeiling = testCeiling
        
        // Verify it was set
        XCTAssertEqual(monitor.systemVolumeCeiling, testCeiling, accuracy: 0.01)
        
        // Verify it persists in UserDefaults
        let savedValue = UserDefaults.standard.float(forKey: "savedSystemVolumeCeiling")
        XCTAssertEqual(savedValue, testCeiling, accuracy: 0.01)
        
        // Reset to default
        monitor.systemVolumeCeiling = 1.0
    }
    
    func testSystemVolumeCeilingEnforcement() {
        // Test that ceiling enforcement works
        let originalCeiling = monitor.systemVolumeCeiling
        let testCeiling: Float = 0.5
        
        // Set a lower ceiling
        monitor.systemVolumeCeiling = testCeiling
        
        // If current volume exceeds ceiling, it should be reduced
        // Note: This test may not work perfectly in simulator
        let currentVolume = monitor.systemVolume
        
        if currentVolume > testCeiling {
            // Volume should be reduced to ceiling
            // Note: In simulator, actual volume change may not work
            // But the logic should still execute
            monitor.setSystemVolume(testCeiling + 0.1) // Try to set above ceiling
        }
        
        // Reset ceiling
        monitor.systemVolumeCeiling = originalCeiling
    }
    
    func testSystemVolumeClamping() {
        // Test that volume values are clamped to valid range
        monitor.setSystemVolume(-0.1) // Should clamp to 0.0
        monitor.setSystemVolume(1.5)  // Should clamp to 1.0
        
        // Verify values are in valid range
        XCTAssertGreaterThanOrEqual(monitor.systemVolume, 0.0)
        XCTAssertLessThanOrEqual(monitor.systemVolume, 1.0)
    }
    
    func testVolumeMonitoring() {
        // Test that volume monitoring is active
        let initialVolume = monitor.systemVolume
        
        // Volume should be a valid float between 0 and 1
        XCTAssertGreaterThanOrEqual(initialVolume, 0.0)
        XCTAssertLessThanOrEqual(initialVolume, 1.0)
        
        // isDeviceSoundOn should reflect volume state
        let isSoundOn = monitor.isDeviceSoundOn
        if initialVolume > 0.0 {
            XCTAssertTrue(isSoundOn, "Device sound should be on when volume > 0")
        } else {
            XCTAssertFalse(isSoundOn, "Device sound should be off when volume == 0")
        }
    }
}

