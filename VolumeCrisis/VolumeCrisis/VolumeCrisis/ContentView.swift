import SwiftUI

struct ContentView: View {
    @StateObject var audioManager = AudioManager.shared
    @StateObject var userManager = UserManager()
    @StateObject var systemVolumeMonitor = SystemVolumeMonitor.shared
    @State private var showUserSheet = false
    @State private var showPresetSheet = false
    @State private var showEditPresetSheet = false
    @State private var editingPreset: VolumePreset?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    // User section with proper spacing
                    VStack(spacing: 8) {
                        Text("Current User: \(userManager.selectedUser?.name ?? "None")")
                            .font(.headline)
                        Button("Switch User") { showUserSheet = true }
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                
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
                                            audioManager.volume = preset.volume
                                        }
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Button(action: {
                                            if let user = userManager.selectedUser {
                                                showEditPresetSheet = true
                                                editingPreset = preset
                                            }
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

                // System Volume Safety Ceiling Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Volume Safety")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Current System Volume: \(Int(systemVolumeMonitor.systemVolume * 100))%")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            Text("Safety Ceiling: \(Int(systemVolumeMonitor.systemVolumeCeiling * 100))%")
                                .font(.headline)
                            Text("(Maximum allowed iPad volume - enforced automatically)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $systemVolumeMonitor.systemVolumeCeiling, in: 0.1...1.0)
                                .accentColor(.orange)
                                .onChange(of: systemVolumeMonitor.systemVolumeCeiling) { oldValue, newValue in
                                    // If current volume exceeds new ceiling, reduce it
                                    if systemVolumeMonitor.systemVolume > newValue {
                                        systemVolumeMonitor.setSystemVolume(newValue)
                                    }
                                    print("System volume ceiling changed to: \(Int(newValue * 100))%")
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
                            print("App volume changed to: \(Int(audioManager.volume * 100))%")
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
                            print("Ceiling changed to: \(Int(newValue * 100))%")
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

                Spacer()
                    .frame(height: 20)
            }
            .padding(.bottom, 20)
            .navigationTitle("Volume Crisis")
            .sheet(isPresented: $showUserSheet) {
                UserSelectionView(userManager: userManager)
            }
            .sheet(isPresented: $showPresetSheet) {
                AddPresetView(userManager: userManager)
            }
            .sheet(isPresented: $showEditPresetSheet) {
                if let preset = editingPreset {
                    EditPresetView(userManager: userManager, preset: preset)
                }
            }
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

struct UserSelectionView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    @State private var newUserName = ""

    var body: some View {
        VStack {
            List {
                ForEach(userManager.users) { user in
                    Button(user.name) {
                        userManager.selectUser(user)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            HStack {
                TextField("New user name", text: $newUserName)
                Button("Add") {
                    userManager.addUser(name: newUserName)
                    newUserName = ""
                }
            }.padding()
        }
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
                    print("Adding preset: \(presetName) with volume: \(presetVolume)")
                    userManager.addPreset(to: user, preset: newPreset)
                    print("Current presets count: \(userManager.selectedUser?.presets.count ?? 0)")
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
