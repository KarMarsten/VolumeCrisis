//
//  UserProfileTests.swift
//  VolumeCrisisTests
//
//  Created by Kar Marsten on 12/27/24.
//

import XCTest
@testable import VolumeCrisis

final class UserProfileTests: XCTestCase {
    
    func testUserProfileCreation() {
        // Test creating a user profile
        let userId = UUID()
        let userName = "Test User"
        let presets = [
            VolumePreset(id: UUID(), name: "Preset 1", volume: 0.5),
            VolumePreset(id: UUID(), name: "Preset 2", volume: 0.7)
        ]
        
        let user = UserProfile(id: userId, name: userName, presets: presets)
        
        XCTAssertEqual(user.id, userId)
        XCTAssertEqual(user.name, userName)
        XCTAssertEqual(user.presets.count, 2)
        XCTAssertEqual(user.presets[0].name, "Preset 1")
        XCTAssertEqual(user.presets[1].name, "Preset 2")
    }
    
    func testVolumePresetCreation() {
        // Test creating a volume preset
        let presetId = UUID()
        let presetName = "Test Preset"
        let presetVolume: Float = 0.6
        
        let preset = VolumePreset(id: presetId, name: presetName, volume: presetVolume)
        
        XCTAssertEqual(preset.id, presetId)
        XCTAssertEqual(preset.name, presetName)
        XCTAssertEqual(preset.volume, presetVolume, accuracy: 0.01)
    }
    
    func testUserProfileCodable() {
        // Test that UserProfile can be encoded and decoded
        let user = UserProfile(
            id: UUID(),
            name: "Test User",
            presets: [
                VolumePreset(id: UUID(), name: "Preset 1", volume: 0.5)
            ]
        )
        
        // Encode
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(user) else {
            XCTFail("Failed to encode UserProfile")
            return
        }
        
        // Decode
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(UserProfile.self, from: encoded) else {
            XCTFail("Failed to decode UserProfile")
            return
        }
        
        // Verify
        XCTAssertEqual(decoded.id, user.id)
        XCTAssertEqual(decoded.name, user.name)
        XCTAssertEqual(decoded.presets.count, user.presets.count)
        XCTAssertEqual(decoded.presets[0].name, user.presets[0].name)
    }
    
    func testVolumePresetCodable() {
        // Test that VolumePreset can be encoded and decoded
        let preset = VolumePreset(id: UUID(), name: "Test Preset", volume: 0.7)
        
        // Encode
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(preset) else {
            XCTFail("Failed to encode VolumePreset")
            return
        }
        
        // Decode
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(VolumePreset.self, from: encoded) else {
            XCTFail("Failed to decode VolumePreset")
            return
        }
        
        // Verify
        XCTAssertEqual(decoded.id, preset.id)
        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.volume, preset.volume, accuracy: 0.01)
    }
    
    func testUserProfileEquatable() {
        // Test UserProfile equality
        let id = UUID()
        let user1 = UserProfile(id: id, name: "User", presets: [])
        let user2 = UserProfile(id: id, name: "User", presets: [])
        let user3 = UserProfile(id: UUID(), name: "User", presets: [])
        
        XCTAssertEqual(user1, user2, "Users with same ID should be equal")
        XCTAssertNotEqual(user1, user3, "Users with different IDs should not be equal")
    }
    
    func testVolumePresetEquatable() {
        // Test VolumePreset equality
        let id = UUID()
        let preset1 = VolumePreset(id: id, name: "Preset", volume: 0.5)
        let preset2 = VolumePreset(id: id, name: "Preset", volume: 0.5)
        let preset3 = VolumePreset(id: UUID(), name: "Preset", volume: 0.5)
        
        XCTAssertEqual(preset1, preset2, "Presets with same ID should be equal")
        XCTAssertNotEqual(preset1, preset3, "Presets with different IDs should not be equal")
    }
}

