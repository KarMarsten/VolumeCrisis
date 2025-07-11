import Foundation

class UserManager: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var selectedUser: UserProfile?

    init() {
        // Default user if none saved
        let defaultUser = UserProfile(id: UUID(), name: "Default", presets: [
            VolumePreset(id: UUID(), name: "Evening", volume: 0.3),
            VolumePreset(id: UUID(), name: "Normal", volume: 0.7)
        ])
        users = [defaultUser]
        selectedUser = defaultUser
    }

    func addUser(name: String) {
        let newUser = UserProfile(id: UUID(), name: name, presets: [])
        users.append(newUser)
    }

    func addPreset(to user: UserProfile, preset: VolumePreset) {
        guard let index = users.firstIndex(of: user) else { return }
        users[index].presets.append(preset)
    }

    func selectUser(_ user: UserProfile) {
        selectedUser = user
    }
}