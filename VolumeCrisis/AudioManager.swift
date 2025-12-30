import Foundation
import AVFoundation
import AudioToolbox

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    
    private let volumeKey = "savedAppVolume"
    private let volumeCeilingKey = "savedAppVolumeCeiling"
    
    @Published var volume: Float = 0.5 {
        didSet {
            player?.volume = min(volume, volumeCeiling)
            audioPlayerNode?.volume = min(volume, volumeCeiling)
            saveVolume()
        }
    }
    @Published var volumeCeiling: Float = 1.0 {
        didSet {
            saveVolumeCeiling()
        }
    }
    @Published var isPlaying: Bool = false
    
    private init() {
        loadVolume()
        loadVolumeCeiling()
    }
    
    private func saveVolume() {
        UserDefaults.standard.set(volume, forKey: volumeKey)
    }
    
    private func loadVolume() {
        if UserDefaults.standard.object(forKey: volumeKey) != nil {
            volume = UserDefaults.standard.float(forKey: volumeKey)
        }
    }
    
    private func saveVolumeCeiling() {
        UserDefaults.standard.set(volumeCeiling, forKey: volumeCeilingKey)
    }
    
    private func loadVolumeCeiling() {
        if UserDefaults.standard.object(forKey: volumeCeilingKey) != nil {
            volumeCeiling = UserDefaults.standard.float(forKey: volumeCeilingKey)
        }
    }

    func playSound(named name: String) {
        debugLog("Attempting to play sound: \(name)", level: .info, category: .audio)
        
        // Try to play bundled audio file first
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            debugLog("Found mp3 file at: \(url)", level: .info, category: .audio)
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.volume = min(volume, volumeCeiling)
                player?.play()
                isPlaying = true
                debugLog("Playing mp3 file successfully", level: .success, category: .audio)
                return
            } catch {
                debugLog("Error playing mp3: \(error.localizedDescription)", level: .error, category: .audio)
            }
        } else {
            debugLog("No mp3 file found, creating tone", level: .info, category: .audio)
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
            debugLog("Playing generated tone with volume: \(min(volume, volumeCeiling))", level: .success, category: .audio)
        } catch {
            debugLog("Error playing tone: \(error.localizedDescription)", level: .error, category: .audio)
            // Fallback to system sound
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            isPlaying = true
        }
    }
    
    func stopSound() {
        debugLog("Stopping sound", level: .info, category: .audio)
        player?.stop()
        audioPlayerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
    }
} 
