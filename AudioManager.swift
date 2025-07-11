import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?
    @Published var volume: Float = 0.5 {
        didSet {
            player?.volume = min(volume, volumeCeiling)
        }
    }
    @Published var volumeCeiling: Float = 1.0

    func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = min(volume, volumeCeiling)
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}