//
//  UserManagerTests.swift
//  VolumeCrisisTests
//
//  Created by Kar Marsten on 12/27/24.
//

import XCTest
@testable import VolumeCrisis

@MainActor
final class UserManagerTests: XCTestCase {
    var userManager: UserManager!
    
    override func setUp() {
        super.setUp()
        userManager = UserManager()
    }
    
    override func tearDown() {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedUsers")
        UserDefaults.standard.removeObject(forKey: "selectedUserId")
        UserDefaults.standard.removeObject(forKey: "volumeRemindersEnabled")
        userManager = nil
        super.tearDown()
    }
    
    func testDefaultUserCreation() {
        // Test that a default user is created if none exist
        XCTAssertNotNil(userManager.selectedUser, "Default user should be created")
        XCTAssertEqual(userManager.selectedUser?.name, "Default")
        XCTAssertGreaterThan(userManager.selectedUser?.presets.count ?? 0, 0, "Default user should have presets")
    }
    
    func testAddUser() {
        // Test adding a new user
        let initialCount = userManager.users.count
        let newUserName = "Test User"
        
        userManager.addUser(name: newUserName)
        
        XCTAssertEqual(userManager.users.count, initialCount + 1, "User count should increase")
        XCTAssertTrue(userManager.users.contains { $0.name == newUserName }, "New user should be in users array")
    }
    
    func testSelectUser() {
        // Test selecting a user
        let testUser = UserProfile(id: UUID(), name: "Test User", presets: [])
        userManager.addUser(name: "Test User")
        
        if let addedUser = userManager.users.first(where: { $0.name == "Test User" }) {
            userManager.selectUser(addedUser)
            XCTAssertEqual(userManager.selectedUser?.id, addedUser.id, "Selected user should match")
        }
    }
    
    func testAddPreset() {
        // Test adding a preset to a user
        guard let selectedUser = userManager.selectedUser else {
            XCTFail("No selected user")
            return
        }
        
        let initialPresetCount = selectedUser.presets.count
        let newPreset = VolumePreset(id: UUID(), name: "Test Preset", volume: 0.5)
        
        userManager.addPreset(to: selectedUser, preset: newPreset)
        
        // Verify preset was added
        if let updatedUser = userManager.users.first(where: { $0.id == selectedUser.id }) {
            XCTAssertEqual(updatedUser.presets.count, initialPresetCount + 1, "Preset count should increase")
            XCTAssertTrue(updatedUser.presets.contains { $0.id == newPreset.id }, "New preset should be in presets array")
        }
    }
    
    func testDeletePreset() {
        // Test deleting a preset
        guard let selectedUser = userManager.selectedUser,
              let firstPreset = selectedUser.presets.first else {
            XCTFail("No user or presets available")
            return
        }
        
        let initialPresetCount = selectedUser.presets.count
        
        userManager.deletePreset(from: selectedUser, preset: firstPreset)
        
        // Verify preset was deleted
        if let updatedUser = userManager.users.first(where: { $0.id == selectedUser.id }) {
            XCTAssertEqual(updatedUser.presets.count, initialPresetCount - 1, "Preset count should decrease")
            XCTAssertFalse(updatedUser.presets.contains { $0.id == firstPreset.id }, "Deleted preset should not be in array")
        }
    }
    
    func testUpdatePreset() {
        // Test updating a preset
        guard let selectedUser = userManager.selectedUser,
              let firstPreset = selectedUser.presets.first else {
            XCTFail("No user or presets available")
            return
        }
        
        let newName = "Updated Preset"
        let newVolume: Float = 0.8
        
        userManager.updatePreset(for: selectedUser, presetId: firstPreset.id, newName: newName, newVolume: newVolume)
        
        // Verify preset was updated
        if let updatedUser = userManager.users.first(where: { $0.id == selectedUser.id }),
           let updatedPreset = updatedUser.presets.first(where: { $0.id == firstPreset.id }) {
            XCTAssertEqual(updatedPreset.name, newName, "Preset name should be updated")
            XCTAssertEqual(updatedPreset.volume, newVolume, accuracy: 0.01, "Preset volume should be updated")
        }
    }
    
    func testUserPersistence() {
        // Test that users persist in UserDefaults
        let testUserName = "Persistent User"
        userManager.addUser(name: testUserName)
        
        // Create a new UserManager instance to test persistence
        let newUserManager = UserManager()
        
        // Verify user was persisted
        XCTAssertTrue(newUserManager.users.contains { $0.name == testUserName }, "User should persist across instances")
    }
    
    func testSelectedUserPersistence() {
        // Test that selected user persists
        guard let selectedUser = userManager.selectedUser else {
            XCTFail("No selected user")
            return
        }
        
        let selectedUserId = selectedUser.id
        
        // Create a new UserManager instance
        let newUserManager = UserManager()
        
        // Verify selected user was persisted
        XCTAssertEqual(newUserManager.selectedUser?.id, selectedUserId, "Selected user should persist across instances")
    }
    
    func testVolumeRemindersEnabledPersistence() {
        // Test that volume reminders setting persists
        userManager.volumeRemindersEnabled = true
        
        // Create a new UserManager instance
        let newUserManager = UserManager()
        
        // Verify setting was persisted
        XCTAssertTrue(newUserManager.volumeRemindersEnabled, "Volume reminders setting should persist")
        
        // Reset
        userManager.volumeRemindersEnabled = false
    }
}

