import SwiftUI

struct ContentView: View {
    @StateObject var audioManager = AudioManager.shared
    @StateObject var userManager = UserManager()
    @State private var showUserSheet = false
    @State private var showPresetSheet = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Current User: \(userManager.selectedUser?.name ?? "None")")
                    .font(.headline)
                    .padding(.top)
                Button("Switch User") { showUserSheet = true }
                    .padding(.bottom, 8)
                if let selectedUser = userManager.selectedUser {
                    List {
                        ForEach(selectedUser.presets) { preset in
                            Button("\(preset.name) (\(Int(preset.volume * 100))%)") {
                                audioManager.volume = preset.volume
                            }
                        }
                    }
                }
                Button("Add Preset") { showPresetSheet = true }
                    .padding(.bottom, 8)

                Text("Volume: \(Int(audioManager.volume * 100))%")
                Slider(value: $audioManager.volume, in: 0...audioManager.volumeCeiling)
                    .accentColor(.blue)
                    .padding()

                Text("Ceiling: \(Int(audioManager.volumeCeiling * 100))%")
                Slider(value: $audioManager.volumeCeiling, in: 0.1...1.0)
                    .accentColor(.red)
                    .padding()

                Button("Play Test Sound") {
                    audioManager.playSound(named: "test")
                }
                .padding()

                Spacer()
            }
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
                    userManager.addPreset(to: user, preset: newPreset)
                }
                presentationMode.wrappedValue.dismiss()
            }
            Spacer()
        }
        .padding()
    }
}