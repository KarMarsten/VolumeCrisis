import AppIntents
import Foundation

// Define volume ceiling options as an AppEnum
@available(iOS 16.0, *)
enum VolumeCeilingLevel: Int, AppEnum {
    case veryLow = 20
    case low = 30
    case mediumLow = 40
    case medium = 50
    case mediumHigh = 60
    case high = 70
    case veryHigh = 80
    case nearMax = 90
    case maximum = 100
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Volume Ceiling Level")
    
    static var caseDisplayRepresentations: [VolumeCeilingLevel: DisplayRepresentation] {
        [
            .veryLow: "20% (Very Low)",
            .low: "30% (Low)",
            .mediumLow: "40% (Medium-Low)",
            .medium: "50% (Medium)",
            .mediumHigh: "60% (Medium-High)",
            .high: "70% (High)",
            .veryHigh: "80% (Very High)",
            .nearMax: "90% (Near Maximum)",
            .maximum: "100% (Maximum)"
        ]
    }
}

@available(iOS 16.0, *)
struct SetVolumeCeilingIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Volume Ceiling"
    static var description = IntentDescription("Set the maximum volume ceiling for your device")
    
    @Parameter(title: "Ceiling Level", description: "Choose the volume ceiling level")
    var ceilingLevel: VolumeCeilingLevel
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set volume ceiling to \(\.$ceilingLevel)")
    }
    
    func perform() async throws -> some IntentResult {
        // Convert percentage to 0-1 range
        let ceilingValue = Float(ceilingLevel.rawValue) / 100.0
        
        // Update the system volume monitor on the main thread
        await MainActor.run {
            SystemVolumeMonitor.shared.systemVolumeCeiling = ceilingValue
        }
        
        return .result(dialog: "Volume ceiling set to \(ceilingLevel.rawValue)%")
    }
}

@available(iOS 16.0, *)
struct GetVolumeCeilingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Volume Ceiling"
    static var description = IntentDescription("Get the current volume ceiling setting")
    
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let currentCeiling = await MainActor.run {
            SystemVolumeMonitor.shared.systemVolumeCeiling
        }
        
        let percentage = Int(currentCeiling * 100)
        
        return .result(value: percentage, dialog: "Current volume ceiling is \(percentage)%")
    }
}

@available(iOS 16.0, *)
struct GetCurrentVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Volume"
    static var description = IntentDescription("Get the current system volume level")
    
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let currentVolume = await MainActor.run {
            SystemVolumeMonitor.shared.systemVolume
        }
        
        let percentage = Int(currentVolume * 100)
        
        return .result(value: percentage, dialog: "Current volume is \(percentage)%")
    }
}

// App Shortcuts provider to make intents discoverable
@available(iOS 16.0, *)
struct VolumeCrisisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetVolumeCeilingIntent(),
            phrases: [
                "Set volume ceiling in \(.applicationName)",
                "Change volume limit in \(.applicationName)",
                "Adjust max volume in \(.applicationName)"
            ],
            shortTitle: "Set Volume Ceiling",
            systemImageName: "speaker.wave.3"
        )
        
        AppShortcut(
            intent: GetVolumeCeilingIntent(),
            phrases: [
                "What's my volume ceiling in \(.applicationName)",
                "Get volume limit in \(.applicationName)",
                "Check volume ceiling in \(.applicationName)"
            ],
            shortTitle: "Get Volume Ceiling",
            systemImageName: "speaker.wave.2"
        )
        
        AppShortcut(
            intent: GetCurrentVolumeIntent(),
            phrases: [
                "What's my current volume in \(.applicationName)",
                "Check volume in \(.applicationName)",
                "Get volume level in \(.applicationName)"
            ],
            shortTitle: "Get Current Volume",
            systemImageName: "speaker.wave.1"
        )
    }
}
