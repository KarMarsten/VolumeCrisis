import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class SystemVolumeMonitor: NSObject, ObservableObject {
    static let shared = SystemVolumeMonitor()
    
    @Published var isDeviceSoundOn: Bool = true
    @Published var systemVolume: Float = 0.0
    @Published var systemVolumeCeiling: Float = 1.0 {
        didSet {
            // Enforce ceiling immediately if current volume exceeds it
            if systemVolume > systemVolumeCeiling {
                setSystemVolume(systemVolumeCeiling)
            }
        }
    }
    
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    
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
        
        // Setup MPVolumeView for system volume control
        setupVolumeControl()
    }
    
    private func setupVolumeControl() {
        // Create hidden MPVolumeView to access the system volume slider
        // Note: MPVolumeView must be added to a view hierarchy to work
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            self.volumeView?.isHidden = true
            
            // Add to window so it's in the view hierarchy (required for MPVolumeView to work)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(self.volumeView!)
            }
            
            // Find the volume slider in the MPVolumeView
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for subview in self.volumeView?.subviews ?? [] {
                    if let slider = subview as? UISlider {
                        self.volumeSlider = slider
                        print("System volume slider found and ready")
                        break
                    }
                }
            }
        }
    }
    
    func setSystemVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        
        // Use MPVolumeView slider to set system volume
        DispatchQueue.main.async { [weak self] in
            if let slider = self?.volumeSlider {
                slider.value = clampedVolume
                print("System volume set to: \(Int(clampedVolume * 100))%")
            } else {
                // Retry setup if slider not found
                self?.setupVolumeControl()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.volumeSlider?.value = clampedVolume
                }
            }
        }
    }
    
    private func startMonitoring() {
        // Get initial volume
        systemVolume = AVAudioSession.sharedInstance().outputVolume
        isDeviceSoundOn = systemVolume > 0.0
        
        // Observe volume changes using KVO (event-driven, battery efficient)
        audioSession?.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
        
        // Periodic check as backup (reduced frequency to save battery)
        // KVO handles most volume changes, this is just a safety net
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
        
        // Enforce volume ceiling - if volume exceeds ceiling, reduce it
        if newVolume > systemVolumeCeiling {
            print("System volume (\(Int(newVolume * 100))%) exceeds ceiling (\(Int(systemVolumeCeiling * 100))%), reducing...")
            setSystemVolume(systemVolumeCeiling)
            // Wait a moment for the volume to update, then check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let updatedVolume = self?.audioSession?.outputVolume {
                    self?.systemVolume = updatedVolume
                }
            }
            return
        }
        
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
        
        // Create a longer silent buffer (1 second) to reduce scheduling overhead
        // Longer buffer = fewer callbacks = better battery life
        let sampleRate: Double = 44100
        let duration: Double = 1.0
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
            // Use a weak capture to avoid retain cycles
            func scheduleBuffer() {
                playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                    // Reschedule when buffer finishes to create infinite loop
                    guard let self = self, self.backgroundEngine != nil else { return }
                    scheduleBuffer()
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
        // Clean up volume view
        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }
}

