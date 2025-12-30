import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var audioManager = AudioManager.shared
    @StateObject var userManager = UserManager()
    @StateObject var systemVolumeMonitor = SystemVolumeMonitor.shared
    @StateObject var debugLogger = DebugLogger.shared
    @State private var showPresetSheet = false
    @State private var showEditPresetSheet = false
    @State private var editingPreset: VolumePreset?
    @State private var showDebugView = false
    
    private func handlePresetTap(preset: VolumePreset) {
        // Set system volume first (this affects all apps)
        let presetVolume = preset.volume
        let ceiling = systemVolumeMonitor.systemVolumeCeiling
        let clampedVolume = min(presetVolume, ceiling)
        
        let presetName = preset.name
        let clampedPercent = Int(clampedVolume * 100)
        let ceilingPercent = Int(ceiling * 100)
        debugLog("Preset '\(presetName)' tapped: Setting volume to \(clampedPercent)% (ceiling: \(ceilingPercent)%)", level: .info, category: .ui)
        
        systemVolumeMonitor.setSystemVolume(clampedVolume)
        // Also update app volume for test sound
        audioManager.volume = clampedVolume
        
        // Verify volume was set after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let actualVolume = AVAudioSession.sharedInstance().outputVolume
            let volumeDiff = abs(actualVolume - clampedVolume)
            let expectedPercent = Int(clampedVolume * 100)
            let actualPercent = Int(actualVolume * 100)
            
            if volumeDiff > 0.05 {
                debugLog("WARNING: Preset volume not applied correctly. Expected: \(expectedPercent)%, Actual: \(actualPercent)%", level: .warning, category: .volume)
                let sliderAvailable = systemVolumeMonitor.isSliderAvailable
                let sliderStatus = systemVolumeMonitor.sliderStatus
                debugLog("Volume slider available: \(sliderAvailable), Status: \(sliderStatus)", level: .debug, category: .slider)
            } else {
                debugLog("Preset volume applied successfully: \(actualPercent)%", level: .success, category: .volume)
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    // Volume Guide Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume Guide")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            VolumeGuideCard(title: "YouTube", description: "Video content", recommendedVolume: 0.6, color: .red)
                            VolumeGuideCard(title: "Music", description: "Background music", recommendedVolume: 0.4, color: .blue)
                            VolumeGuideCard(title: "Podcasts", description: "Speech content", recommendedVolume: 0.7, color: .green)
                            VolumeGuideCard(title: "Gaming", description: "Interactive content", recommendedVolume: 0.5, color: .orange)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
                
                // Presets Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume Presets")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let selectedUser = userManager.selectedUser {
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 8) {
                                ForEach(selectedUser.presets) { preset in
                                    HStack {
                                        Button("\(preset.name) (\(Int(preset.volume * 100))%)") {
                                            handlePresetTap(preset: preset)
                                        }
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Button(action: {
                                            editingPreset = preset
                                            showEditPresetSheet = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Button(action: {
                                            if let user = userManager.selectedUser {
                                                userManager.deletePreset(from: user, preset: preset)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 150)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    Button("Add Preset") { showPresetSheet = true }
                        .foregroundColor(.green)
                        .padding(.horizontal)
                }
                .padding(.bottom, 8)

                // Settings Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Volume Reminders")
                            Spacer()
                            Toggle("", isOn: $userManager.volumeRemindersEnabled)
                                .onChange(of: userManager.volumeRemindersEnabled) { oldValue, newValue in
                                    if newValue {
                                        userManager.scheduleVolumeReminder()
                                    } else {
                                        userManager.cancelVolumeReminders()
                                    }
                                }
                        }
                        .padding(.horizontal)
                        
                        if userManager.volumeRemindersEnabled {
                            Text("You'll get hourly reminders to check your volume")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 8)

                // System Volume Control Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Volume Control")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        VStack(spacing: 8) {
                            Text("System Volume: \(Int(systemVolumeMonitor.systemVolume * 100))%")
                                .font(.headline)
                            if systemVolumeMonitor.isRunningOniPad {
                                Text("(iPadOS - Use physical volume buttons to change)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Note: iPadOS restricts programmatic volume control. Use physical buttons, then the app will enforce the safety ceiling.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                            } else {
                                Text("(iOS - Controls actual iPhone volume - affects all apps)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if systemVolumeMonitor.canControlSystemVolume {
                                // On iOS (iPhone), allow direct volume control via slider
                                Slider(value: Binding(
                                    get: { systemVolumeMonitor.systemVolume },
                                    set: { newValue in
                                        // Clamp to ceiling if one is set
                                        let clampedValue = min(newValue, systemVolumeMonitor.systemVolumeCeiling)
                                        systemVolumeMonitor.setSystemVolume(clampedValue)
                                    }
                                ), in: 0...systemVolumeMonitor.systemVolumeCeiling)
                                    .accentColor(.blue)
                                    .onChange(of: systemVolumeMonitor.systemVolume) { oldValue, newValue in
                                        debugLog("System volume changed to: \(Int(newValue * 100))%", level: .info, category: .volume)
                                    }
                            } else {
                                // On iPadOS, show read-only display (volume controlled via physical buttons)
                                // Slider is disabled - user must use physical buttons
                                Slider(value: Binding(
                                    get: { systemVolumeMonitor.systemVolume },
                                    set: { _ in
                                        // No-op: Slider is read-only on iPadOS
                                        // Volume can only be changed via physical buttons
                                    }
                                ), in: 0...systemVolumeMonitor.systemVolumeCeiling)
                                    .accentColor(.gray)
                                    .disabled(true)
                                Text("Use physical volume buttons to change. App will enforce safety ceiling.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        VStack(spacing: 8) {
                            Text("Safety Ceiling: \(Int(systemVolumeMonitor.systemVolumeCeiling * 100))%")
                                .font(.headline)
                            if systemVolumeMonitor.isRunningOniPad {
                                Text("(Maximum allowed iPad volume - enforced automatically when exceeded)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Adjust this slider to set your maximum volume limit")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                
                                // Diagnostic info for iPadOS
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Diagnostics:")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                    
                                    HStack {
                                        Text("Slider: \(systemVolumeMonitor.sliderStatus)")
                                            .font(.caption2)
                                        Spacer()
                                    }
                                    .foregroundColor(systemVolumeMonitor.isSliderFunctional ? .green : .orange)
                                    
                                    if !systemVolumeMonitor.isSliderFunctional && systemVolumeMonitor.sliderStatus.contains("NOT FUNCTIONAL") {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("⚠️ CRITICAL LIMITATION")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                            Text("Ceiling enforcement cannot work on this device. This is a hardware/OS limitation on some older iPads - programmatic volume control is blocked by the system.")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Text("Alternative: Use iOS Settings > Screen Time > Content & Privacy Restrictions > Volume Limit")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .padding(.top, 2)
                                        }
                                        .padding(.top, 2)
                                    }
                                    
                                    Text("Last enforcement: \(systemVolumeMonitor.lastEnforcementAttempt)")
                                        .font(.caption2)
                                    
                                    Text("Success: \(systemVolumeMonitor.enforcementSuccessCount), Failures: \(systemVolumeMonitor.enforcementFailureCount)")
                                        .font(.caption2)
                                    
                                    Button("Test Enforcement") {
                                        systemVolumeMonitor.forceEnforcementTest()
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            } else {
                                Text("(Maximum allowed iPhone volume - enforced automatically)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            // Ceiling slider - fully adjustable on all platforms
                            Slider(value: $systemVolumeMonitor.systemVolumeCeiling, in: 0.1...1.0)
                                .accentColor(.orange)
                                .onChange(of: systemVolumeMonitor.systemVolumeCeiling) { oldValue, newValue in
                                    debugLog("System volume ceiling changed from \(Int(oldValue * 100))% to \(Int(newValue * 100))%", level: .info, category: .volume)
                                    
                                    // If current volume exceeds new ceiling, reduce it
                                    if systemVolumeMonitor.systemVolume > newValue {
                                        debugLog("Current volume (\(Int(systemVolumeMonitor.systemVolume * 100))%) exceeds new ceiling (\(Int(newValue * 100))%), reducing volume...", level: .warning, category: .enforcement)
                                        systemVolumeMonitor.setSystemVolume(newValue)
                                    }
                                }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)

                // App Volume Control Section
                VStack(spacing: 8) {
                    Text("App Volume: \(Int(audioManager.volume * 100))%")
                        .font(.headline)
                    Text("(This controls the test sound only)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $audioManager.volume, in: 0...audioManager.volumeCeiling)
                        .accentColor(.blue)
                        .onChange(of: audioManager.volume) { oldValue, newValue in
                            // Ensure volume doesn't exceed ceiling
                            if newValue > audioManager.volumeCeiling {
                                audioManager.volume = audioManager.volumeCeiling
                            }
                            debugLog("App volume changed to: \(Int(audioManager.volume * 100))%", level: .info, category: .volume)
                        }
                        .onChange(of: audioManager.volumeCeiling) { oldValue, newCeiling in
                            // If ceiling is reduced below current volume, adjust volume
                            if audioManager.volume > newCeiling {
                                audioManager.volume = newCeiling
                            }
                        }
                }
                .padding()

                VStack(spacing: 8) {
                    Text("Ceiling: \(Int(audioManager.volumeCeiling * 100))%")
                        .font(.headline)
                    Text("(Maximum volume limit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $audioManager.volumeCeiling, in: 0.1...1.0)
                        .accentColor(.red)
                        .onChange(of: audioManager.volumeCeiling) { oldValue, newValue in
                            debugLog("Ceiling changed to: \(Int(newValue * 100))%", level: .info, category: .volume)
                        }
                }
                .padding()

                HStack(spacing: 16) {
                    Button("Play Test Sound") {
                        audioManager.playSound(named: "test")
                    }
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("Stop Test Sound") {
                        audioManager.stopSound()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Debug Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Debug")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $debugLogger.isEnabled)
                            .onChange(of: debugLogger.isEnabled) { oldValue, newValue in
                                debugLog("Debug logging \(newValue ? "enabled" : "disabled")", level: .info, category: .general)
                            }
                    }
                    .padding(.horizontal)
                    
                    Button("Show Debug Logs") {
                        showDebugView = true
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    
                    Button("Clear Debug Logs") {
                        debugLogger.clear()
                        debugLog("Debug logs cleared", level: .info, category: .general)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)

                Spacer()
                    .frame(height: 20)
            }
            .padding(.bottom, 20)
            .navigationTitle("Volume Crisis")
            .sheet(isPresented: $showPresetSheet) {
                AddPresetView(userManager: userManager)
            }
            .sheet(isPresented: $showEditPresetSheet) {
                if let preset = editingPreset {
                    EditPresetView(userManager: userManager, preset: preset)
                }
            }
            .sheet(isPresented: $showDebugView) {
                DebugView()
            }
        }
    }
}

struct DebugView: View {
    @StateObject var debugLogger = DebugLogger.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: LogCategory? = nil
    @State private var selectedLevel: LogLevel? = nil
    
    var filteredLogs: [DebugLogEntry] {
        var logs = debugLogger.logs
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        return logs.reversed() // Show newest first
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter controls
                HStack {
                    Menu("Category: \(selectedCategory?.rawValue ?? "All")") {
                        Button("All") { selectedCategory = nil }
                        ForEach([LogCategory.general, .volume, .audio, .ui, .background, .enforcement, .slider], id: \.self) { category in
                            Button(category.rawValue) { selectedCategory = category }
                        }
                    }
                    
                    Menu("Level: \(selectedLevel?.emoji ?? "All")") {
                        Button("All") { selectedLevel = nil }
                        ForEach([LogLevel.debug, .info, .warning, .error, .success], id: \.self) { level in
                            Button("\(level.emoji) \(level.name)") { selectedLevel = level }
                        }
                    }
                }
                .padding()
                
                // Log list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { log in
                            HStack(alignment: .top, spacing: 8) {
                                Text(log.level.emoji)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(log.category.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(log.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(log.message)
                                        .font(.caption)
                                        .foregroundColor(log.level.color)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(log.level.color.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Debug Logs (\(filteredLogs.count))")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct VolumeGuideCard: View {
    let title: String
    let description: String
    let recommendedVolume: Float
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Recommended: \(Int(recommendedVolume * 100))%")
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(width: 120)
    }
}

struct AddPresetView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    @State private var presetName: String = ""
    @State private var presetVolume: Float = 0.5

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Preset")
                .font(.headline)
            TextField("Preset Name", text: $presetName)
            HStack {
                Text("Volume: \(Int(presetVolume * 100))%")
                Slider(value: $presetVolume, in: 0...1)
            }
            Button("Add") {
                if let user = userManager.selectedUser {
                    let newPreset = VolumePreset(id: UUID(), name: presetName, volume: presetVolume)
                    debugLog("Adding preset: \(presetName) with volume: \(presetVolume)", level: .info, category: .ui)
                    userManager.addPreset(to: user, preset: newPreset)
                    debugLog("Current presets count: \(userManager.selectedUser?.presets.count ?? 0)", level: .debug, category: .ui)
                }
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(presetName.isEmpty)
            Spacer()
        }
        .padding()
    }
}

struct EditPresetView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    let preset: VolumePreset
    @State private var presetName: String = ""
    @State private var presetVolume: Float = 0.5
    
    init(userManager: UserManager, preset: VolumePreset) {
        self.userManager = userManager
        self.preset = preset
        _presetName = State(initialValue: preset.name)
        _presetVolume = State(initialValue: preset.volume)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Edit Preset")
                .font(.headline)
            TextField("Preset Name", text: $presetName)
            HStack {
                Text("Volume: \(Int(presetVolume * 100))%")
                Slider(value: $presetVolume, in: 0...1)
            }
            HStack(spacing: 16) {
                Button("Delete") {
                    if let user = userManager.selectedUser {
                        userManager.deletePreset(from: user, preset: preset)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Save") {
                    if let user = userManager.selectedUser {
                        userManager.updatePreset(for: user, presetId: preset.id, newName: presetName, newVolume: presetVolume)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(presetName.isEmpty)
            }
            Spacer()
        }
        .padding()
    }
}
}
