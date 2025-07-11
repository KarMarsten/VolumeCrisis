import SwiftUI

struct ContentView: View {
    @StateObject var audioManager = AudioManager.shared
    @StateObject var userManager = UserManager()
    @State private var showUserSheet = false
    @State private var showPresetSheet = false
    @State private var showVolumeGuide = false
    @State private var selectedScenario = ""
    @State private var showVolumeBarPrompt = false
    @State private var promptVolume: Float = 0.5

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
                                    Button("\(preset.name) (\(Int(preset.volume * 100))%)") {
                                        audioManager.volume = preset.volume
                                    }
                                    .foregroundColor(.blue)
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

                // Interactive Volume Bar Prompt
                if showVolumeBarPrompt {
                    InteractiveVolumeBar(volume: $promptVolume, ceiling: audioManager.volumeCeiling) { newVolume in
                        audioManager.volume = newVolume
                        showVolumeBarPrompt = false
                        print("Volume changed to: \(Int(newVolume * 100))%")
                    } onCancel: {
                        showVolumeBarPrompt = false
                    }
                    .padding()
                } else {
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
                }

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

                Button("Play Test Sound") {
                    audioManager.playSound(named: "test")
                }
                .padding()
                
                Button("Test Volume Change") {
                    // Test volume change
                    audioManager.volume = 0.2
                    print("Testing volume change to 20%")
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("Stop Test Sound") {
                    audioManager.stopSound()
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)

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
        }
    }
}

// Interactive Volume Bar Prompt
struct InteractiveVolumeBar: View {
    @Binding var volume: Float
    let ceiling: Float
    let onSet: (Float) -> Void
    let onCancel: () -> Void
    @State private var willReset = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Set Your App Volume")
                .font(.headline)
            Text("(Controls test sound volume)")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Text("Low")
                    .foregroundColor(.blue)
                Spacer()
                Text("Medium")
                    .foregroundColor(.green)
                Spacer()
                Text("High")
                    .foregroundColor(.orange)
                Spacer()
                Text("Max")
                    .foregroundColor(.red)
            }
            .font(.caption)
            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                    Capsule()
                        .fill(barColor(for: volume))
                        .frame(width: CGFloat(volume/ceiling) * geo.size.width, height: 16)
                }
                .frame(height: 16)
                Slider(value: $volume, in: 0...ceiling)
                    .opacity(0.01)
            }
            .frame(height: 24)
            Text("Current: \(Int(volume * 100))%")
                .font(.subheadline)
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                Spacer()
                Button("Set Volume") {
                    let selectedVolume = volume
                    let percent = selectedVolume / ceiling
                    
                    // Check if volume is in High or Max range
                    if percent >= 0.6 {
                        willReset = true
                        // Set to medium (60%) after 1 second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onSet(0.6)
                        }
                    } else {
                        onSet(selectedVolume)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 8))
        .padding()
    }

    func barColor(for value: Float) -> Color {
        let percent = value / ceiling
        switch percent {
        case ..<0.2:
            return .blue
        case 0.2..<0.6:
            return .green
        case 0.6..<0.9:
            return .orange
        default:
            return .red
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
}