import Foundation
import UserNotifications

class UserManager: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var selectedUser: UserProfile?
    @Published var volumeRemindersEnabled = false

    init() {
        // Default user if none saved
        let defaultUser = UserProfile(id: UUID(), name: "Default", presets: [
            VolumePreset(id: UUID(), name: "Evening", volume: 0.3),
            VolumePreset(id: UUID(), name: "Normal", volume: 0.7),
            VolumePreset(id: UUID(), name: "YouTube", volume: 0.6),
            VolumePreset(id: UUID(), name: "Music", volume: 0.4),
            VolumePreset(id: UUID(), name: "Podcasts", volume: 0.7)
        ])
        users = [defaultUser]
        selectedUser = defaultUser
        
        requestNotificationPermission()
    }

    func addUser(name: String) {
        let newUser = UserProfile(id: UUID(), name: name, presets: [])
        users.append(newUser)
    }

    func addPreset(to user: UserProfile, preset: VolumePreset) {
        // Find user by ID instead of using Equatable
        guard let index = users.firstIndex(where: { $0.id == user.id }) else {
            print("User not found in users array")
            return
        }
        print("Adding preset to user: \(user.name) at index: \(index)")
        users[index].presets.append(preset)
        print("Users array presets count: \(users[index].presets.count)")
        
        // Update selectedUser reference to point to the updated user
        if selectedUser?.id == user.id {
            selectedUser = users[index]
            print("Updated selectedUser, presets count: \(selectedUser?.presets.count ?? 0)")
        }
    }

    func selectUser(_ user: UserProfile) {
        selectedUser = user
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
