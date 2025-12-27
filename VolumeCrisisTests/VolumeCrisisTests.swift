//
//  VolumeCrisisTests.swift
//  VolumeCrisisTests
//
//  Created by Kar Marsten on 7/11/25.
//

import Testing
@testable import VolumeCrisis

struct VolumeCrisisTests {
    
    @Test func appInitializes() async throws {
        // Test that the app can initialize without crashing
        let audioManager = AudioManager.shared
        let systemMonitor = SystemVolumeMonitor.shared
        let userManager = UserManager()
        
        // Verify singletons exist
        #expect(audioManager != nil)
        #expect(systemMonitor != nil)
        #expect(userManager != nil)
    }
    
    @Test func defaultUserExists() async throws {
        // Test that default user is created
        let userManager = UserManager()
        #expect(userManager.selectedUser != nil)
        #expect(userManager.selectedUser?.name == "Default")
    }
    
    @Test func volumeDefaults() async throws {
        // Test default volume values
        let audioManager = AudioManager.shared
        #expect(audioManager.volume >= 0.0)
        #expect(audioManager.volume <= 1.0)
        #expect(audioManager.volumeCeiling >= 0.0)
        #expect(audioManager.volumeCeiling <= 1.0)
    }
    
    @Test func systemVolumeDefaults() async throws {
        // Test default system volume values
        let systemMonitor = SystemVolumeMonitor.shared
        #expect(systemMonitor.systemVolume >= 0.0)
        #expect(systemMonitor.systemVolume <= 1.0)
        #expect(systemMonitor.systemVolumeCeiling >= 0.0)
        #expect(systemMonitor.systemVolumeCeiling <= 1.0)
    }
}
