import Foundation
import AVFoundation

class SystemVolumeMonitor: NSObject, ObservableObject {
    static let shared = SystemVolumeMonitor()
    
    @Published var isDeviceSoundOn: Bool = true
    @Published var systemVolume: Float = 0.0
    
    private var audioSession: AVAudioSession?
    private var monitoringTimer: Timer?
    private var backgroundEngine: AVAudioEngine?
    private var backgroundPlayerNode: AVAudioPlayerNode?
    
    private override init() {
        super.init()
        setupAudioSession()
        startMonitoring()
    }
    
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
            print("Audio session configured for background playback")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    private func startMonitoring() {
        // Get initial volume
        systemVolume = AVAudioSession.sharedInstance().outputVolume
        isDeviceSoundOn = systemVolume > 0.0
        
        // Observe volume changes using KVO
        audioSession?.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
        
        // Start periodic checks as backup
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkVolume()
        }
        RunLoop.main.add(monitoringTimer!, forMode: .common)
        
        // Start background audio if sound is on
        if isDeviceSoundOn {
            startBackgroundAudio()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            DispatchQueue.main.async {
                self.checkVolume()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func checkVolume() {
        let newVolume = AVAudioSession.sharedInstance().outputVolume
        let wasSoundOn = isDeviceSoundOn
        
        systemVolume = newVolume
        isDeviceSoundOn = newVolume > 0.0
        
        // If sound just turned on, start background audio
        if !wasSoundOn && isDeviceSoundOn {
            startBackgroundAudio()
        }
        
        // If sound turned off, stop background audio
        if wasSoundOn && !isDeviceSoundOn {
            stopBackgroundAudio()
        }
    }
    
    private func startBackgroundAudio() {
        // Create a silent audio loop to keep the app running in background
        guard backgroundEngine == nil else { return }
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        // Create a very short silent buffer (100ms)
        let sampleRate: Double = 44100
        let duration: Double = 0.1
        let frameCount = Int(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("Failed to create audio format")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Fill with silence (zeros)
        if let channelData = buffer.floatChannelData {
            channelData[0].initialize(repeating: 0.0, count: Int(buffer.frameLength))
        }
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        do {
            try audioEngine.start()
            playerNode.volume = 0.0 // Silent
            playerNode.play()
            
            // Schedule buffer to loop continuously
            func scheduleBuffer() {
                playerNode.scheduleBuffer(buffer, at: nil, options: []) {
                    // Reschedule when buffer finishes to create infinite loop
                    DispatchQueue.main.async {
                        if self.backgroundEngine != nil {
                            scheduleBuffer()
                        }
                    }
                }
            }
            scheduleBuffer()
            
            // Keep references to prevent deallocation
            self.backgroundEngine = audioEngine
            self.backgroundPlayerNode = playerNode
            
            print("Background audio started - app will run in background")
        } catch {
            print("Failed to start background audio: \(error.localizedDescription)")
        }
    }
    
    private func stopBackgroundAudio() {
        backgroundPlayerNode?.stop()
        backgroundEngine?.stop()
        backgroundPlayerNode = nil
        backgroundEngine = nil
        print("Background audio stopped")
    }
    
    deinit {
        monitoringTimer?.invalidate()
        audioSession?.removeObserver(self, forKeyPath: "outputVolume")
        stopBackgroundAudio()
    }
}

