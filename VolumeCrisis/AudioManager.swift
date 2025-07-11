import Foundation
import AVFoundation
import AudioToolbox

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    @Published var volume: Float = 0.5 {
        didSet {
            player?.volume = min(volume, volumeCeiling)
            audioPlayerNode?.volume = min(volume, volumeCeiling)
        }
    }
    @Published var volumeCeiling: Float = 1.0
    @Published var isPlaying: Bool = false

    func playSound(named name: String) {
        print("Attempting to play sound: \(name)")
        
        // Try to play bundled audio file first
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            print("Found mp3 file at: \(url)")
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.volume = min(volume, volumeCeiling)
                player?.play()
                isPlaying = true
                print("Playing mp3 file successfully")
                return
            } catch {
                print("Error playing mp3: \(error.localizedDescription)")
            }
        } else {
            print("No mp3 file found, creating tone")
        }
        
        // Create a simple tone that respects volume
        createAndPlayTone()
    }
    
    private func createAndPlayTone() {
        // Create audio engine
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        // Create a simple sine wave tone
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let frequency: Double = 440.0 // A4 note
        
        let frameCount = Int(sampleRate * duration)
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: engine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: AVAudioFrameCount(frameCount))!
        
        // Generate sine wave
        for frame in 0..<frameCount {
            let sample = sin(2.0 * Double.pi * frequency * Double(frame) / sampleRate)
            audioBuffer.floatChannelData![0][frame] = Float(sample * 0.3) // Reduce amplitude
        }
        audioBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Connect and play
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioBuffer.format)
        
        do {
            try engine.start()
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: .interrupts, completionHandler: {
                DispatchQueue.main.async {
                    self.isPlaying = false
                }
            })
            playerNode.volume = min(volume, volumeCeiling)
            playerNode.play()
            isPlaying = true
            print("Playing generated tone with volume: \(min(volume, volumeCeiling))")
        } catch {
            print("Error playing tone: \(error.localizedDescription)")
            // Fallback to system sound
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            isPlaying = true
        }
    }
    
    func stopSound() {
        print("Stopping sound")
        player?.stop()
        audioPlayerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
    }
} 