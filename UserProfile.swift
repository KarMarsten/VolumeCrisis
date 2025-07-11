import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var presets: [VolumePreset]
}

struct VolumePreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var volume: Float
}