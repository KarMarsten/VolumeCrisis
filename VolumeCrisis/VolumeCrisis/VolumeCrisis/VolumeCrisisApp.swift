import SwiftUI

@main
struct VolumeCrisisApp: App {
    @StateObject private var volumeMonitor = SystemVolumeMonitor.shared
    
    init() {
        // Initialize background monitoring when app launches
        _ = SystemVolumeMonitor.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
} 