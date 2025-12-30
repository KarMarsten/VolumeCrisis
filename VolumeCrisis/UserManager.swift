import Foundation
import UserNotifications

class UserManager: ObservableObject {
    @Published var users: [UserProfile] = [] {
        didSet {
            saveUsers()
        }
    }
    @Published var selectedUser: UserProfile? {
        didSet {
            saveSelectedUser()
        }
    }
    @Published var volumeRemindersEnabled = false {
        didSet {
            saveVolumeRemindersEnabled()
        }
    }
    
    private let usersKey = "savedUsers"
    private let selectedUserIdKey = "selectedUserId"
    private let volumeRemindersEnabledKey = "volumeRemindersEnabled"

    init() {
        loadUsers()
        loadSelectedUser()
        loadVolumeRemindersEnabled()
        
        // If no users loaded, create default user
        if users.isEmpty {
            let defaultUser = UserProfile(id: UUID(), name: "Default", presets: [
                VolumePreset(id: UUID(), name: "Evening", volume: 0.3),
                VolumePreset(id: UUID(), name: "Normal", volume: 0.7),
                VolumePreset(id: UUID(), name: "YouTube", volume: 0.6),
                VolumePreset(id: UUID(), name: "Music", volume: 0.4),
                VolumePreset(id: UUID(), name: "Podcasts", volume: 0.7)
            ])
            users = [defaultUser]
            selectedUser = defaultUser
        }
        
        requestNotificationPermission()
    }
    
    private func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
            debugLog("Users saved to UserDefaults", level: .info, category: .general)
        }
    }
    
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let decoded = try? JSONDecoder().decode([UserProfile].self, from: data) {
            users = decoded
            debugLog("Users loaded from UserDefaults: \(users.count) users", level: .info, category: .general)
        }
    }
    
    private func saveSelectedUser() {
        if let selectedUser = selectedUser {
            UserDefaults.standard.set(selectedUser.id.uuidString, forKey: selectedUserIdKey)
            debugLog("Selected user saved: \(selectedUser.name)", level: .info, category: .general)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedUserIdKey)
        }
    }
    
    private func loadSelectedUser() {
        if let selectedIdString = UserDefaults.standard.string(forKey: selectedUserIdKey),
           let selectedId = UUID(uuidString: selectedIdString) {
            selectedUser = users.first { $0.id == selectedId }
            if selectedUser != nil {
                debugLog("Selected user loaded: \(selectedUser?.name ?? "Unknown")", level: .info, category: .general)
            }
        }
        // If no selected user found, use first user
        if selectedUser == nil && !users.isEmpty {
            selectedUser = users.first
        }
    }
    
    private func saveVolumeRemindersEnabled() {
        UserDefaults.standard.set(volumeRemindersEnabled, forKey: volumeRemindersEnabledKey)
    }
    
    private func loadVolumeRemindersEnabled() {
        volumeRemindersEnabled = UserDefaults.standard.bool(forKey: volumeRemindersEnabledKey)
    }

    func addUser(name: String) {
        let newUser = UserProfile(id: UUID(), name: name, presets: [])
        users.append(newUser)
        // Save is automatic via didSet
    }

    func addPreset(to user: UserProfile, preset: VolumePreset) {
        // Find user by ID instead of using Equatable
        guard let index = users.firstIndex(where: { $0.id == user.id }) else {
            debugLog("User not found in users array", level: .error, category: .ui)
            return
        }
        debugLog("Adding preset to user: \(user.name) at index: \(index)", level: .info, category: .ui)
        users[index].presets.append(preset)
        debugLog("Users array presets count: \(users[index].presets.count)", level: .debug, category: .ui)
        
        // Save users (didSet will trigger automatically, but we call saveUsers directly for clarity)
        saveUsers()
        
        // Update selectedUser reference to point to the updated user
        if selectedUser?.id == user.id {
            selectedUser = users[index]
            debugLog("Updated selectedUser, presets count: \(selectedUser?.presets.count ?? 0)", level: .debug, category: .ui)
        }
    }

    func selectUser(_ user: UserProfile) {
        selectedUser = user
        // Save is automatic via didSet
    }
    
    func deletePreset(from user: UserProfile, preset: VolumePreset) {
        guard let userIndex = users.firstIndex(where: { $0.id == user.id }) else {
            debugLog("User not found", level: .error, category: .ui)
            return
        }
        
        users[userIndex].presets.removeAll { $0.id == preset.id }
        
        // Save users
        saveUsers()
        
        // Update selectedUser if it's the same user
        if selectedUser?.id == user.id {
            selectedUser = users[userIndex]
        }
    }
    
    func updatePreset(for user: UserProfile, presetId: UUID, newName: String, newVolume: Float) {
        guard let userIndex = users.firstIndex(where: { $0.id == user.id }) else {
            debugLog("User not found", level: .error, category: .ui)
            return
        }
        
        if let presetIndex = users[userIndex].presets.firstIndex(where: { $0.id == presetId }) {
            users[userIndex].presets[presetIndex] = VolumePreset(id: presetId, name: newName, volume: newVolume)
            
            // Save users
            saveUsers()
            
            // Update selectedUser if it's the same user
            if selectedUser?.id == user.id {
                selectedUser = users[userIndex]
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.volumeRemindersEnabled = granted
            }
        }
    }
    
    func scheduleVolumeReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Volume Check"
        content.body = "Remember to check your volume level before starting media!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true) // Every hour
        let request = UNNotificationRequest(identifier: "volumeReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelVolumeReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["volumeReminder"])
    }
} 
