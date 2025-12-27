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
        
        // Ensure volume slider is set up early - critical for iPadOS ceiling enforcement
        // On older devices, give more time for window to be available
        let delay = isRunningOniPad ? 1.0 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.setupVolumeControl()
            // On older iPads, also retry after a longer delay as backup
            if self?.isRunningOniPad == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    if self?.volumeSlider == nil {
                        print("⚠️ Retrying volume slider setup for older iPad...")
                        self?.setupVolumeControl()
                    }
                }
            }
        }
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
        // On older iPads, this may take longer or need different handling
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove old volume view if it exists
            self.volumeView?.removeFromSuperview()
            
            self.volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            self.volumeView?.isHidden = true
            self.volumeView?.showsVolumeSlider = true
            self.volumeView?.showsRouteButton = false
            
            // Try multiple methods to find window (for compatibility with older iOS versions)
            var window: UIWindow?
            
            // Method 1: Modern window scene approach (iOS 13+)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let foundWindow = windowScene.windows.first {
                window = foundWindow
            }
            
            // Method 2: Fallback for older iOS versions
            if window == nil {
                if let appDelegate = UIApplication.shared.delegate,
                   let foundWindow = appDelegate.window {
                    window = foundWindow
                }
            }
            
            // Method 3: Direct window access (last resort)
            if window == nil {
                window = UIApplication.shared.windows.first
            }
            
            if let window = window {
                window.addSubview(self.volumeView!)
                print("MPVolumeView added to window (method: \(window.description))")
            } else {
                print("⚠️ Error: Could not find window to add MPVolumeView - will retry")
                // Retry after a delay - sometimes window isn't ready immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.setupVolumeControl()
                }
                return
            }
            
            // Find the volume slider in the MPVolumeView
            // On older iPads, this may take more attempts - increase retry count
            let maxAttempts = self.isRunningOniPad ? 30 : 20
            func findSlider(attempt: Int = 0) {
                guard attempt < maxAttempts else {
                    print("⚠️ Error: Could not find system volume slider after \(maxAttempts) attempts")
                    if self.isRunningOniPad {
                        print("⚠️ iPadOS: This may be an older device compatibility issue. Try restarting the app.")
                    }
                    return
                }
                
                // Search recursively through subviews
                // Optimized to avoid deep recursion and reduce main thread blocking
                func searchSubviews(_ view: UIView, depth: Int = 0) -> UISlider? {
                    // Limit search depth to avoid performance issues on complex view hierarchies
                    guard depth < 10 else { return nil }
                    
                    // Check current view first
                    if let slider = view as? UISlider {
                        return slider
                    }
                    
                    // Search subviews (limit to first 20 to avoid blocking on complex hierarchies)
                    let subviewsToSearch = Array(view.subviews.prefix(20))
                    for subview in subviewsToSearch {
                        if let slider = searchSubviews(subview, depth: depth + 1) {
                            return slider
                        }
                    }
                    return nil
                }
                
                if let volumeView = self.volumeView, let slider = searchSubviews(volumeView, depth: 0) {
                    self.volumeSlider = slider
                    print("✅ System volume slider found and ready (attempt \(attempt + 1))")
                    print("Current slider value: \(Int(slider.value * 100))%")
                    return
                }
                
                // Retry if not found - use longer delay on older devices
                // Use async to avoid blocking main thread
                let delay = self.isRunningOniPad ? 0.15 : 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
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
                // This should only happen from UI (which is disabled), so silently return
                return
            }
            // On iPadOS, we CAN reduce volume to enforce ceiling
            // This is the key functionality for ceiling enforcement
            print("iPadOS: Enforcing ceiling - reducing volume from \(Int(systemVolume * 100))% to \(Int(clampedVolume * 100))%")
        }
        
        // Set flag to prevent checkVolume from overriding our change
        // Use a longer grace period to ensure volume change completes
        isSettingVolume = true
        lastVolumeSetAttempt = Date()
        
        // Use MPVolumeView slider to set system volume
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure slider is available
            // This is CRITICAL for ceiling enforcement on iPadOS
            if self.volumeSlider == nil {
                print("⚠️ Warning: Volume slider not found, attempting to setup...")
                // Retry setup if slider not found - this is critical for iPadOS ceiling enforcement
                self.setupVolumeControl()
                
                // On iPadOS, we need the slider for ceiling enforcement - retry more aggressively
                var retryCount = 0
                let maxRetries = self.isRunningOniPad ? 5 : 3
                
                func retryVolumeSet() {
                    guard retryCount < maxRetries else {
                        print("❌ Error: Volume slider still not found after \(maxRetries) retries. Ceiling enforcement may not work.")
                        if self.isRunningOniPad {
                            print("⚠️ iPadOS: Without volume slider, ceiling enforcement will not work. Try restarting the app.")
                        }
                        return
                    }
                    
                    retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount) * 0.3) { [weak self] in
                        guard let self = self else { return }
                        if let slider = self.volumeSlider {
                            slider.value = clampedVolume
                            slider.sendActions(for: .valueChanged)
                            print("✅ Volume set after retry \(retryCount) to: \(Int(clampedVolume * 100))%")
                        } else {
                            // Retry again
                            retryVolumeSet()
                        }
                    }
                }
                retryVolumeSet()
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
                        // Check if we're actually trying to increase from the original system volume
                        // (not from actualVolume which might be different due to timing/slider issues)
                        let originalVolume = self.systemVolume
                        let isActuallyIncreasing = clampedVolume > originalVolume
                        
                        if clampedVolume > actualVolume {
                            // Only warn if:
                            // 1. We're actually trying to increase from original volume (not just a timing issue)
                            // 2. The difference is significant (> 8% to avoid false positives on older devices)
                            let difference = clampedVolume - actualVolume
                            if isActuallyIncreasing && difference > 0.08 {
                                print("iPadOS: Cannot increase volume programmatically (Expected: \(Int(clampedVolume * 100))%, Actual: \(Int(actualVolume * 100))%). Use physical volume buttons.")
                            }
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
        
        // Periodic check as backup - more frequent to catch volume changes from other apps
        // KVO handles most volume changes, but this ensures we catch changes from other apps
        // Reduced to 2 seconds for better responsiveness, especially for ceiling enforcement
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkVolume()
        }
        RunLoop.main.add(monitoringTimer!, forMode: .common)
        
        // Always start background audio to keep app running in background
        // This is critical for ceiling enforcement when app is in background
        startBackgroundAudio()
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
        
        // CRITICAL: Enforce volume ceiling FIRST - this must always work, even if we're setting volume
        // Ceiling enforcement takes priority over everything else for safety
        if newVolume > systemVolumeCeiling {
            // Don't let isSettingVolume block ceiling enforcement - safety first!
            // If we're in the middle of setting volume, we still need to enforce ceiling
            if isSettingVolume {
                // If we're setting volume but it exceeded ceiling, we need to enforce
                // Reset the flag to allow enforcement
                print("⚠️ Volume exceeded ceiling during volume set operation - enforcing ceiling immediately")
                isSettingVolume = false
            }
            print("⚠️ System volume (\(Int(newVolume * 100))%) exceeds ceiling (\(Int(systemVolumeCeiling * 100))%), enforcing ceiling...")
            
            // Update UI immediately to show we're enforcing
            systemVolume = systemVolumeCeiling
            
            // Reduce volume to ceiling
            // On iPadOS, this will work because we're reducing (not increasing)
            setSystemVolume(systemVolumeCeiling)
            
            // Verify the reduction worked after a delay
            // On iPadOS, we may need multiple attempts to reduce volume
            var verificationAttempt = 0
            let maxVerificationAttempts = isRunningOniPad ? 5 : 3
            
            func verifyAndRetry() {
                verificationAttempt += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if let updatedVolume = self.audioSession?.outputVolume {
                        if updatedVolume > self.systemVolumeCeiling {
                            // Volume still exceeds ceiling - retry enforcement
                            if verificationAttempt < maxVerificationAttempts {
                                print("⚠️ Volume still exceeds ceiling after attempt \(verificationAttempt). Current: \(Int(updatedVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%. Retrying...")
                                self.setSystemVolume(self.systemVolumeCeiling)
                                verifyAndRetry()
                            } else {
                                print("❌ Failed to enforce ceiling after \(maxVerificationAttempts) attempts. Current: \(Int(updatedVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%")
                                if self.isRunningOniPad {
                                    print("⚠️ iPadOS: Volume slider may not be available. Try restarting the app.")
                                }
                            }
                        } else {
                            // Successfully enforced ceiling
                            self.systemVolume = updatedVolume
                            print("✅ Ceiling enforced successfully after \(verificationAttempt) attempt(s). Volume: \(Int(updatedVolume * 100))%")
                        }
                    }
                }
            }
            verifyAndRetry()
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
        // This is CRITICAL for ceiling enforcement when app is in background
        // Always start background audio to ensure app stays active for monitoring
        if let existingEngine = backgroundEngine {
            // Already running, but verify it's still active
            if existingEngine.isRunning == false {
                print("Background audio stopped unexpectedly - restarting...")
                stopBackgroundAudio()
                // Continue to start new background audio below
            } else {
                return // Already running
            }
        }
        
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

