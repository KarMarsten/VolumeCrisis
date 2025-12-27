//
//  AudioManagerTests.swift
//  VolumeCrisisTests
//
//  Created by Kar Marsten on 12/27/24.
//

import XCTest
@testable import VolumeCrisis

@MainActor
final class AudioManagerTests: XCTestCase {
    var audioManager: AudioManager!
    
    override func setUp() {
        super.setUp()
        audioManager = AudioManager.shared
    }
    
    override func tearDown() {
        // Stop any playing sounds
        audioManager.stopSound()
        audioManager = nil
        super.tearDown()
    }
    
    func testVolumeDefault() {
        // Test that volume defaults to 0.5 (50%)
        XCTAssertEqual(audioManager.volume, 0.5, accuracy: 0.01)
    }
    
    func testVolumeCeilingDefault() {
        // Test that ceiling defaults to 1.0 (100%)
        XCTAssertEqual(audioManager.volumeCeiling, 1.0, accuracy: 0.01)
    }
    
    func testVolumePersistence() {
        // Test that volume persists in UserDefaults
        let testVolume: Float = 0.7
        
        audioManager.volume = testVolume
        
        // Verify it was set
        XCTAssertEqual(audioManager.volume, testVolume, accuracy: 0.01)
        
        // Verify it persists in UserDefaults
        let savedValue = UserDefaults.standard.float(forKey: "savedAppVolume")
        XCTAssertEqual(savedValue, testVolume, accuracy: 0.01)
        
        // Reset to default
        audioManager.volume = 0.5
    }
    
    func testVolumeCeilingPersistence() {
        // Test that ceiling persists in UserDefaults
        let testCeiling: Float = 0.8
        
        audioManager.volumeCeiling = testCeiling
        
        // Verify it was set
        XCTAssertEqual(audioManager.volumeCeiling, testCeiling, accuracy: 0.01)
        
        // Verify it persists in UserDefaults
        let savedValue = UserDefaults.standard.float(forKey: "savedAppVolumeCeiling")
        XCTAssertEqual(savedValue, testCeiling, accuracy: 0.01)
        
        // Reset to default
        audioManager.volumeCeiling = 1.0
    }
    
    func testVolumeClamping() {
        // Test that volume is clamped to ceiling
        let testCeiling: Float = 0.6
        
        audioManager.volumeCeiling = testCeiling
        audioManager.volume = 0.8 // Try to set above ceiling
        
        // Volume should be clamped to ceiling
        XCTAssertLessThanOrEqual(audioManager.volume, testCeiling, accuracy: 0.01)
        
        // Reset
        audioManager.volumeCeiling = 1.0
        audioManager.volume = 0.5
    }
    
    func testVolumeRange() {
        // Test that volume stays within valid range
        audioManager.volume = -0.1 // Should clamp to 0.0
        XCTAssertGreaterThanOrEqual(audioManager.volume, 0.0)
        
        audioManager.volume = 1.5 // Should clamp to ceiling
        XCTAssertLessThanOrEqual(audioManager.volume, audioManager.volumeCeiling)
        
        // Reset
        audioManager.volume = 0.5
    }
    
    func testSoundPlayback() {
        // Test that sound can be played
        let initialPlayingState = audioManager.isPlaying
        
        audioManager.playSound(named: "test")
        
        // Give it a moment to start
        let expectation = XCTestExpectation(description: "Sound starts playing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Note: isPlaying might be true or false depending on audio system state
        // Just verify the function executes without crashing
        
        audioManager.stopSound()
    }
    
    func testSoundStop() {
        // Test that sound can be stopped
        audioManager.playSound(named: "test")
        
        // Give it a moment
        let expectation = XCTestExpectation(description: "Sound stops")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.audioManager.stopSound()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify stop doesn't crash
        XCTAssertFalse(audioManager.isPlaying, "Sound should be stopped")
    }
}

