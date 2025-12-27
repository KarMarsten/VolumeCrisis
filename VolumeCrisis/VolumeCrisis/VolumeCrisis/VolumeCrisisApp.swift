import SwiftUI

@main
struct VolumeCrisisApp: App {
    @StateObject private var volumeMonitor = SystemVolumeMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
} 