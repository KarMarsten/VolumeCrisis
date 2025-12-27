import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class SystemVolumeMonitor: NSObject, ObservableObject {
    static let shared = SystemVolumeMonitor()
    
    @Published var isDeviceSoundOn: Bool = true
    @Published var systemVolume: Float = 0.0
    private let systemVolumeCeilingKey = "savedSystemVolumeCeiling"
    
    // Detect if running on iPad (iPadOS) vs iPhone (iOS)
    var isRunningOniPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // System volume control capability
    // On iPadOS, apps have limited ability to change system volume programmatically
    // On iOS (iPhone), system volume control works better
    var canControlSystemVolume: Bool {
        return !isRunningOniPad // Better support on iPhone
    }
    
    @Published var systemVolumeCeiling: Float = 1.0 {
        didSet {
            // Enforce ceiling immediately if current volume exceeds it
            if systemVolume > systemVolumeCeiling {
                setSystemVolume(systemVolumeCeiling)
            }
            saveSystemVolumeCeiling()
        }
    }
    
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    
    private var audioSession: AVAudioSession?
    private var monitoringTimer: Timer?
    private var backgroundEngine: AVAudioEngine?
    private var backgroundPlayerNode: AVAudioPlayerNode?
    
    // Flag to prevent checkVolume from overriding user-initiated volume changes
    private var isSettingVolume: Bool = false
    private var lastVolumeSetAttempt: Date?
    
    private override init() {
        super.init()
        loadSystemVolumeCeiling()
        setupAudioSession()
        startMonitoring()
    }
    
    private func saveSystemVolumeCeiling() {
        UserDefaults.standard.set(systemVolumeCeiling, forKey: systemVolumeCeilingKey)
    }
    
    private func loadSystemVolumeCeiling() {
        if UserDefaults.standard.object(forKey: systemVolumeCeilingKey) != nil {
            systemVolumeCeiling = UserDefaults.standard.float(forKey: systemVolumeCeilingKey)
        }
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
            
            // Remove old volume view if it exists
            self.volumeView?.removeFromSuperview()
            
            self.volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            self.volumeView?.isHidden = true
            self.volumeView?.showsVolumeSlider = true
            self.volumeView?.showsRouteButton = false
            
            // Add to window so it's in the view hierarchy (required for MPVolumeView to work)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(self.volumeView!)
                print("MPVolumeView added to window")
            } else {
                print("Error: Could not find window to add MPVolumeView")
            }
            
            // Find the volume slider in the MPVolumeView
            // Try multiple times as the slider may not be immediately available
            func findSlider(attempt: Int = 0) {
                guard attempt < 20 else {
                    print("Error: Could not find system volume slider after 20 attempts")
                    return
                }
                
                // Search recursively through subviews
                func searchSubviews(_ view: UIView) -> UISlider? {
                    if let slider = view as? UISlider {
                        return slider
                    }
                    for subview in view.subviews {
                        if let slider = searchSubviews(subview) {
                            return slider
                        }
                    }
                    return nil
                }
                
                if let volumeView = self.volumeView, let slider = searchSubviews(volumeView) {
                    self.volumeSlider = slider
                    print("System volume slider found and ready (attempt \(attempt + 1))")
                    print("Current slider value: \(Int(slider.value * 100))%")
                    return
                }
                
                // Retry if not found
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    findSlider(attempt: attempt + 1)
                }
            }
            findSlider()
        }
    }
    
    func setSystemVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        
        // On iPadOS, we can only reduce volume (enforce ceiling), not increase it
        // On iOS, we can set volume in both directions
        if isRunningOniPad {
            if clampedVolume > systemVolume {
                // Trying to increase volume on iPadOS - this won't work
                // Silently return - UI slider is disabled so this shouldn't be called from UI
                return
            }
            // On iPadOS, we CAN reduce volume to enforce ceiling
            // This is the key functionality for ceiling enforcement
        }
        
        // Set flag to prevent checkVolume from overriding our change
        // Use a longer grace period to ensure volume change completes
        isSettingVolume = true
        lastVolumeSetAttempt = Date()
        
        // Use MPVolumeView slider to set system volume
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure slider is available
            if self.volumeSlider == nil {
                print("Warning: Volume slider not found, attempting to setup...")
                // Retry setup if slider not found
                self.setupVolumeControl()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if let slider = self.volumeSlider {
                        slider.value = clampedVolume
                        slider.sendActions(for: .valueChanged)
                        print("Volume set after retry to: \(Int(clampedVolume * 100))%")
                    } else {
                        print("Error: Volume slider still not found after retry. Volume control may be limited.")
                        #if targetEnvironment(simulator)
                        print("Note: System volume control may not work in iOS Simulator. Try on a physical device.")
                        #endif
                    }
                }
                return
            }
            
            // Set the volume value
            guard let slider = self.volumeSlider else {
                print("Error: Volume slider is nil - attempting to find it...")
                // Try to setup volume control again
                self.setupVolumeControl()
                // Retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, let slider = self.volumeSlider else {
                        print("Error: Volume slider still not found. Ceiling enforcement may be limited.")
                        return
                    }
                    slider.value = clampedVolume
                    slider.sendActions(for: .valueChanged)
                    print("Volume set after retry to: \(Int(clampedVolume * 100))%")
                }
                return
            }
            
            let currentSliderValue = slider.value
            print("Setting system volume slider to: \(Int(clampedVolume * 100))% (current slider: \(Int(currentSliderValue * 100))%)")
            
            // On iPadOS, we're reducing volume (enforcing ceiling), so this should work
            if self.isRunningOniPad {
                print("iPadOS: Reducing volume to enforce ceiling: \(Int(clampedVolume * 100))%")
            }
            
            slider.value = clampedVolume
            // Trigger value changed event to ensure the change takes effect
            slider.sendActions(for: .valueChanged)
            
            // Update our tracked volume immediately for UI responsiveness
            self.systemVolume = clampedVolume
            
            // Update our tracked volume after a delay to get actual system volume
            // Use longer delay to ensure volume change completes before allowing checkVolume to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                self.isSettingVolume = false
                
                if let updatedVolume = self.audioSession?.outputVolume {
                    let actualVolume = updatedVolume
                    
                    if self.canControlSystemVolume {
                        // On iOS, check if volume change took effect
                        if abs(actualVolume - clampedVolume) < 0.05 {
                            // Volume change succeeded
                            self.systemVolume = actualVolume
                            print("iOS: Volume successfully changed to: \(Int(actualVolume * 100))%")
                        } else {
                            // Volume change didn't work - might be simulator limitation
                            #if targetEnvironment(simulator)
                            print("iOS Simulator: Volume control may not work in simulator. Expected: \(Int(clampedVolume * 100))%, Got: \(Int(actualVolume * 100))%")
                            print("Note: System volume control works better on physical devices.")
                            // Keep UI at requested value since simulator limitations
                            self.systemVolume = clampedVolume
                            #else
                            print("iOS: Volume change may not have taken effect. Expected: \(Int(clampedVolume * 100))%, Got: \(Int(actualVolume * 100))%")
                            print("Note: If volume slider is not found, volume control may be limited.")
                            // Still update to actual volume to reflect reality
                            self.systemVolume = actualVolume
                            #endif
                        }
                    } else {
                        // On iPadOS, if trying to increase volume, it won't work
                        if clampedVolume > actualVolume {
                            // User tried to increase volume - this won't work on iPadOS
                            print("iPadOS: Cannot increase volume programmatically (Expected: \(Int(clampedVolume * 100))%, Actual: \(Int(actualVolume * 100))%). Use physical volume buttons.")
                            // Keep UI at requested value for visual feedback, but note it didn't work
                            // The actual system volume will be updated when user uses physical buttons
                        } else if clampedVolume < actualVolume {
                            // User tried to decrease volume - this should work (enforcing ceiling)
                            self.systemVolume = actualVolume
                            print("iPadOS: Volume reduced to: \(Int(actualVolume * 100))% (enforcing ceiling)")
                        } else {
                            // Volume is the same - no change needed
                            self.systemVolume = actualVolume
                        }
                    }
                }
            }
            
            print("System volume set to: \(Int(clampedVolume * 100))%")
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
        // Don't override volume if we're actively setting it
        if isSettingVolume {
            // Check if enough time has passed since last volume set attempt
            if let lastAttempt = lastVolumeSetAttempt, Date().timeIntervalSince(lastAttempt) < 1.0 {
                return // Still within the grace period
            } else {
                // Grace period expired, reset flag
                isSettingVolume = false
            }
        }
        
        let newVolume = AVAudioSession.sharedInstance().outputVolume
        let wasSoundOn = isDeviceSoundOn
        
        // Enforce volume ceiling - if volume exceeds ceiling, reduce it
        // This is critical functionality - must work on both iOS and iPadOS
        if newVolume > systemVolumeCeiling {
            print("⚠️ System volume (\(Int(newVolume * 100))%) exceeds ceiling (\(Int(systemVolumeCeiling * 100))%), enforcing ceiling...")
            
            // Update UI immediately to show we're enforcing
            systemVolume = systemVolumeCeiling
            
            // Reduce volume to ceiling
            // On iPadOS, this will work because we're reducing (not increasing)
            setSystemVolume(systemVolumeCeiling)
            
            // Verify the reduction worked after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if let updatedVolume = self.audioSession?.outputVolume {
                    if updatedVolume > self.systemVolumeCeiling {
                        // Volume still exceeds ceiling - retry enforcement
                        print("⚠️ Volume still exceeds ceiling after reduction attempt. Current: \(Int(updatedVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%. Retrying...")
                        self.setSystemVolume(self.systemVolumeCeiling)
                    } else {
                        // Successfully enforced ceiling
                        self.systemVolume = updatedVolume
                        print("✅ Ceiling enforced successfully. Volume: \(Int(updatedVolume * 100))%")
                    }
                }
            }
            return
        }
        
        // Only update systemVolume if we're not actively setting it
        // On both iOS and iPadOS, only sync when volume actually changed significantly
        // This prevents overriding user-initiated volume changes that are still in progress
        if !isSettingVolume {
            if canControlSystemVolume {
                // On iOS, only sync if volume changed significantly
                // This allows programmatic changes to complete before syncing
                if abs(newVolume - systemVolume) > 0.02 {
                    systemVolume = newVolume
                    print("iOS: System volume changed to: \(Int(newVolume * 100))%")
                }
            } else {
                // On iPadOS, only update if volume changed significantly (user used physical buttons)
                if abs(newVolume - systemVolume) > 0.02 {
                    systemVolume = newVolume
                    print("iPadOS: System volume changed via physical buttons to: \(Int(newVolume * 100))%")
                }
            }
        }
        
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

