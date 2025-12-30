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
    
    // Public property to check if slider is available (for UI diagnostics)
    var isSliderAvailable: Bool {
        return volumeSlider != nil
    }
    
    private var audioSession: AVAudioSession?
    private var monitoringTimer: Timer?
    private var backgroundEngine: AVAudioEngine?
    private var backgroundPlayerNode: AVAudioPlayerNode?
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Flag to prevent checkVolume from overriding user-initiated volume changes
    private var isSettingVolume: Bool = false
    
    // Diagnostic properties
    @Published var sliderStatus: String = "Unknown"
    @Published var lastEnforcementAttempt: String = "Never"
    @Published var enforcementSuccessCount: Int = 0
    @Published var enforcementFailureCount: Int = 0
    @Published var isSliderFunctional: Bool = false  // Track if slider actually works
    
    private override init() {
        super.init()
        loadSystemVolumeCeiling()
        setupAudioSession()
        setupAppStateObservers()
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
                        debugLog("Retrying volume slider setup for older iPad...", level: .warning, category: .slider)
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
            
            // Configure audio session with proper options for background execution
            // Use .playback category with .mixWithOthers to allow background audio
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            
            // Activate the session
            try audioSession?.setActive(true, options: [])
            debugLog("Audio session configured for background playback", level: .success, category: .audio)
            
            // Add notification observers for audio session interruptions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: audioSession
            )
            
        } catch {
            debugLog("Failed to configure audio session: \(error.localizedDescription)", level: .error, category: .audio)
            // Retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupAudioSession()
            }
        }
        
        // Setup MPVolumeView for system volume control
        setupVolumeControl()
    }
    
    private func setupAppStateObservers() {
        // Observe app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        debugLog("App entering background - ensuring monitoring continues...", level: .info, category: .background)
        // Audio session should keep running for monitoring
    }
    
    @objc private func handleAppDidBecomeActive() {
        debugLog("App became active - verifying monitoring...", level: .info, category: .background)
        // Verify background audio is still running
        if backgroundEngine == nil || backgroundEngine?.isRunning == false {
            debugLog("Background audio stopped - restarting...", level: .warning, category: .background)
            startBackgroundAudio()
        }
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            debugLog("Audio session interruption began", level: .warning, category: .audio)
        case .ended:
            debugLog("Audio session interruption ended", level: .success, category: .audio)
            // Reactivate audio session
            do {
                try audioSession?.setActive(true, options: [])
                // Restart background audio if needed
                if isDeviceSoundOn && backgroundEngine == nil {
                    startBackgroundAudio()
                }
            } catch {
                debugLog("Failed to reactivate audio session: \(error.localizedDescription)", level: .error, category: .audio)
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        debugLog("Audio route changed: \(reason)", level: .info, category: .audio)
        // Re-check volume after route change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkVolume()
        }
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
                debugLog("MPVolumeView added to window (method: \(window.description))", level: .success, category: .slider)
            } else {
                debugLog("Error: Could not find window to add MPVolumeView - will retry", level: .error, category: .slider)
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
                    self.sliderStatus = "NOT FOUND after \(maxAttempts) attempts"
                    debugLog("Error: Could not find system volume slider after \(maxAttempts) attempts", level: .error, category: .slider)
                    if self.isRunningOniPad {
                        debugLog("iPadOS: This may be an older device compatibility issue. Try restarting the app.", level: .warning, category: .slider)
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
                    self.sliderStatus = "Found (attempt \(attempt + 1))"
                    debugLog("System volume slider found and ready (attempt \(attempt + 1))", level: .success, category: .slider)
                    debugLog("Current slider value: \(Int(slider.value * 100))%", level: .info, category: .slider)
                    // Test if slider is functional - delay to avoid blocking initialization
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.testSliderFunctionality()
                    }
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
            debugLog("iPadOS: Enforcing ceiling - reducing volume from \(Int(systemVolume * 100))% to \(Int(clampedVolume * 100))%", level: .info, category: .enforcement)
        }
        
        // Set flag to prevent checkVolume from overriding our change
        // Use a longer grace period to ensure volume change completes
        isSettingVolume = true
        
        // Use MPVolumeView slider to set system volume
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure slider is available
            // This is CRITICAL for ceiling enforcement on iPadOS
            if self.volumeSlider == nil {
                debugLog("Warning: Volume slider not found, attempting to setup...", level: .warning, category: .slider)
                // Retry setup if slider not found - this is critical for iPadOS ceiling enforcement
                self.setupVolumeControl()
                
                // On iPadOS, we need the slider for ceiling enforcement - retry more aggressively
                var retryCount = 0
                let maxRetries = self.isRunningOniPad ? 5 : 3
                
                func retryVolumeSet() {
                    guard retryCount < maxRetries else {
                        debugLog("CRITICAL ERROR: Volume slider still not found after \(maxRetries) retries.", level: .error, category: .slider)
                        debugLog("Ceiling enforcement CANNOT work without the volume slider.", level: .error, category: .enforcement)
                        if self.isRunningOniPad {
                            debugLog("iPadOS: This is a critical failure. Ceiling enforcement will not work.", level: .error, category: .enforcement)
                            debugLog("Possible causes: MPVolumeView not properly initialized, Window not available, Older iPad compatibility issue", level: .warning, category: .slider)
                            debugLog("Try: Restart the app, ensure app is in foreground at least once", level: .info, category: .slider)
                        }
                        // Log the current state for debugging
                        debugLog("Debug Info: Volume slider: \(self.volumeSlider == nil ? "NOT FOUND" : "FOUND"), Volume view: \(self.volumeView == nil ? "nil" : "exists")", level: .debug, category: .slider)
                        debugLog("Debug Info: Current volume: \(Int(self.systemVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%, Is iPad: \(self.isRunningOniPad)", level: .debug, category: .volume)
                        return
                    }
                    
                    retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount) * 0.3) { [weak self] in
                        guard let self = self else { return }
                        if let slider = self.volumeSlider {
                            slider.value = clampedVolume
                            slider.sendActions(for: .valueChanged)
                            debugLog("Volume set after retry \(retryCount) to: \(Int(clampedVolume * 100))%", level: .success, category: .volume)
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
                debugLog("Error: Volume slider is nil - attempting to find it...", level: .error, category: .slider)
                // Try to setup volume control again
                self.setupVolumeControl()
                // Retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, let slider = self.volumeSlider else {
                        debugLog("Error: Volume slider still not found. Ceiling enforcement may be limited.", level: .error, category: .slider)
                        return
                    }
                    slider.value = clampedVolume
                    slider.sendActions(for: .valueChanged)
                    debugLog("Volume set after retry to: \(Int(clampedVolume * 100))%", level: .success, category: .volume)
                }
                return
            }
            
            let currentSliderValue = slider.value
            debugLog("Setting system volume slider to: \(Int(clampedVolume * 100))% (current slider: \(Int(currentSliderValue * 100))%)", level: .info, category: .volume)
            
            // On iPadOS, we're reducing volume (enforcing ceiling), so this should work
            if self.isRunningOniPad {
                debugLog("iPadOS: Reducing volume to enforce ceiling: \(Int(clampedVolume * 100))%", level: .info, category: .enforcement)
            }
            
            // Store original slider value for verification
            let originalSliderValue = slider.value
            debugLog("Slider state: Before=\(Int(originalSliderValue * 100))%, Target=\(Int(clampedVolume * 100))%", level: .debug, category: .slider)
            
            slider.value = clampedVolume
            // Trigger value changed event to ensure the change takes effect
            slider.sendActions(for: .valueChanged)
            
            // Verify slider value was actually set
            let newSliderValue = slider.value
            if abs(newSliderValue - clampedVolume) > 0.01 {
                debugLog("WARNING: Slider value not set correctly! Expected=\(Int(clampedVolume * 100))%, Got=\(Int(newSliderValue * 100))%", level: .warning, category: .slider)
            } else {
                debugLog("Slider value set successfully: \(Int(newSliderValue * 100))%", level: .success, category: .slider)
            }
            
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
                            debugLog("iOS: Volume successfully changed to: \(Int(actualVolume * 100))%", level: .success, category: .volume)
                        } else {
                            // Volume change didn't work - might be simulator limitation
                            #if targetEnvironment(simulator)
                            debugLog("iOS Simulator: Volume control may not work in simulator. Expected: \(Int(clampedVolume * 100))%, Got: \(Int(actualVolume * 100))%", level: .warning, category: .volume)
                            debugLog("Note: System volume control works better on physical devices.", level: .info, category: .volume)
                            // Keep UI at requested value since simulator limitations
                            self.systemVolume = clampedVolume
                            #else
                            debugLog("iOS: Volume change may not have taken effect. Expected: \(Int(clampedVolume * 100))%, Got: \(Int(actualVolume * 100))%", level: .warning, category: .volume)
                            debugLog("Note: If volume slider is not found, volume control may be limited.", level: .info, category: .volume)
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
                                debugLog("iPadOS: Cannot increase volume programmatically (Expected: \(Int(clampedVolume * 100))%, Actual: \(Int(actualVolume * 100))%). Use physical volume buttons.", level: .warning, category: .volume)
                            }
                            // Keep UI at requested value for visual feedback, but note it didn't work
                            // The actual system volume will be updated when user uses physical buttons
                        } else if clampedVolume < actualVolume {
                            // User tried to decrease volume - this should work (enforcing ceiling)
                            self.systemVolume = actualVolume
                            debugLog("iPadOS: Volume reduced to: \(Int(actualVolume * 100))% (enforcing ceiling)", level: .success, category: .enforcement)
                        } else {
                            // Volume is the same - no change needed
                            self.systemVolume = actualVolume
                        }
                    }
                }
            }
            
            debugLog("System volume set to: \(Int(clampedVolume * 100))%", level: .info, category: .volume)
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
        // On iPadOS, use 1 second intervals for faster detection of volume changes from apps like YouTube Kids
        let interval = isRunningOniPad ? 1.0 : 2.0
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkVolume()
        }
        RunLoop.main.add(monitoringTimer!, forMode: .common)
        debugLog("Volume monitoring started: Interval=\(interval)s, KVO=active, Background audio=\(isDeviceSoundOn ? "on" : "off")", level: .success, category: .volume)
        
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
        
        // Log volume changes for debugging (only when significant change or exceeds ceiling)
        if abs(newVolume - systemVolume) > 0.01 || newVolume > systemVolumeCeiling {
            debugLog("Volume check: Current=\(Int(newVolume * 100))%, Tracked=\(Int(systemVolume * 100))%, Ceiling=\(Int(systemVolumeCeiling * 100))%", level: .info, category: .volume)
        }
        
        // CRITICAL: Enforce volume ceiling FIRST - this must always work, even if we're setting volume
        // Ceiling enforcement takes priority over everything else for safety
        if newVolume > systemVolumeCeiling {
            // Don't let isSettingVolume block ceiling enforcement - safety first!
            // If we're in the middle of setting volume, we still need to enforce ceiling
            if isSettingVolume {
                // If we're setting volume but it exceeded ceiling, we need to enforce
                // Reset the flag to allow enforcement
                debugLog("Volume exceeded ceiling during volume set operation - enforcing ceiling immediately", level: .warning, category: .enforcement)
                isSettingVolume = false
            }
            debugLog("System volume (\(Int(newVolume * 100))%) exceeds ceiling (\(Int(systemVolumeCeiling * 100))%), enforcing ceiling...", level: .warning, category: .enforcement)
            
            // Check if we have the volume slider - critical for enforcement
            if volumeSlider == nil {
                debugLog("CRITICAL: Volume slider not available for ceiling enforcement!", level: .error, category: .enforcement)
                debugLog("Attempting emergency slider setup...", level: .warning, category: .slider)
                setupVolumeControl()
                // Wait a moment and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if self.volumeSlider == nil {
                        debugLog("FAILED: Volume slider still not available after emergency setup", level: .error, category: .slider)
                        debugLog("Ceiling enforcement cannot proceed without volume slider", level: .error, category: .enforcement)
                        debugLog("Current state: Volume=\(Int(newVolume * 100))%, Ceiling=\(Int(self.systemVolumeCeiling * 100))%", level: .debug, category: .volume)
                    } else {
                        debugLog("Emergency slider setup successful, enforcing ceiling...", level: .success, category: .slider)
                        self.setSystemVolume(self.systemVolumeCeiling)
                    }
                }
                return
            }
            
            // Check if slider is functional - if test showed it's not functional, don't try
            if !isSliderFunctional && sliderStatus.contains("NOT FUNCTIONAL") {
                debugLog("CRITICAL LIMITATION: Volume slider is not functional on this device", level: .error, category: .slider)
                debugLog("Ceiling enforcement cannot work - slider found but doesn't control system volume", level: .error, category: .enforcement)
                debugLog("This is a hardware/OS limitation on some older iPads", level: .warning, category: .slider)
                debugLog("iOS blocks programmatic volume control on these devices - no workaround available", level: .warning, category: .slider)
                debugLog("Current state: Volume=\(Int(newVolume * 100))%, Ceiling=\(Int(systemVolumeCeiling * 100))%", level: .debug, category: .volume)
                debugLog("Alternative: Use iOS Settings > Screen Time > Content & Privacy Restrictions > Volume Limit", level: .info, category: .general)
                // Don't attempt enforcement - it won't work
                return
            }
            
            // Update UI immediately to show we're enforcing
            systemVolume = systemVolumeCeiling
            
            // Reduce volume to ceiling
            // On iPadOS, this will work because we're reducing (not increasing)
            setSystemVolume(systemVolumeCeiling)
            
            // Update last enforcement attempt timestamp
            lastEnforcementAttempt = Date().formatted(date: .omitted, time: .standard)
            
            // Verify the reduction worked after a delay
            // On iPadOS, we may need multiple attempts to reduce volume
            // Use more aggressive verification on iPadOS
            var verificationAttempt = 0
            let maxVerificationAttempts = isRunningOniPad ? 10 : 3  // More attempts on iPadOS
            
            func verifyAndRetry() {
                verificationAttempt += 1
                // Use shorter delay on iPadOS for faster response
                let delay = isRunningOniPad ? 0.3 : 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
                    if let updatedVolume = self.audioSession?.outputVolume {
                        if updatedVolume > self.systemVolumeCeiling {
                            // Volume still exceeds ceiling - retry enforcement
                            if verificationAttempt < maxVerificationAttempts {
                                debugLog("Volume still exceeds ceiling after attempt \(verificationAttempt). Current: \(Int(updatedVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%. Retrying...", level: .warning, category: .enforcement)
                                
                                // Check if slider is still available
                                if self.volumeSlider == nil {
                                    debugLog("Volume slider lost during enforcement! Re-initializing...", level: .error, category: .slider)
                                    self.setupVolumeControl()
                                    // Wait and retry
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if self.volumeSlider != nil {
                                            self.setSystemVolume(self.systemVolumeCeiling)
                                            verifyAndRetry()
                                        } else {
                                            debugLog("CRITICAL: Cannot enforce ceiling - volume slider unavailable", level: .error, category: .enforcement)
                                        }
                                    }
                                } else {
                                    self.setSystemVolume(self.systemVolumeCeiling)
                                    verifyAndRetry()
                                }
                            } else {
                                self.enforcementFailureCount += 1
                                debugLog("FAILED to enforce ceiling after \(maxVerificationAttempts) attempts.", level: .error, category: .enforcement)
                                debugLog("Current: \(Int(updatedVolume * 100))%, Ceiling: \(Int(self.systemVolumeCeiling * 100))%", level: .error, category: .enforcement)
                                debugLog("Volume slider status: \(self.volumeSlider == nil ? "NOT AVAILABLE" : "AVAILABLE")", level: .error, category: .slider)
                                debugLog("Enforcement stats: Success=\(self.enforcementSuccessCount), Failures=\(self.enforcementFailureCount)", level: .info, category: .enforcement)
                                if self.isRunningOniPad {
                                    debugLog("iPadOS: This indicates a critical issue with volume control.", level: .error, category: .enforcement)
                                    debugLog("Possible solutions: Restart the app, Ensure app was in foreground at least once, Check if MPVolumeView is properly initialized", level: .info, category: .enforcement)
                                }
                            }
                        } else {
                            // Successfully enforced ceiling
                            self.systemVolume = updatedVolume
                            self.enforcementSuccessCount += 1
                            debugLog("Ceiling enforced successfully after \(verificationAttempt) attempt(s). Volume: \(Int(updatedVolume * 100))%", level: .success, category: .enforcement)
                            debugLog("Enforcement stats: Success=\(self.enforcementSuccessCount), Failures=\(self.enforcementFailureCount)", level: .info, category: .enforcement)
                        }
                    } else {
                        debugLog("Warning: Could not read updated volume from audio session", level: .warning, category: .audio)
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
                    debugLog("iOS: System volume changed to: \(Int(newVolume * 100))%", level: .info, category: .volume)
                }
            } else {
                // On iPadOS, only update if volume changed significantly (user used physical buttons)
                if abs(newVolume - systemVolume) > 0.02 {
                    systemVolume = newVolume
                    debugLog("iPadOS: System volume changed via physical buttons to: \(Int(newVolume * 100))%", level: .info, category: .volume)
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
        // Don't start if already running
        guard backgroundEngine == nil || backgroundEngine?.isRunning == false else {
            return
        }
        
        // Register background task BEFORE starting audio
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "VolumeMonitoring") { [weak self] in
            // Expiration handler - clean up gracefully
            debugLog("Background task expiring - cleaning up...", level: .warning, category: .background)
            self?.endBackgroundTask()
        }
        
        guard backgroundTaskID != .invalid else {
            debugLog("Failed to register background task", level: .error, category: .background)
            return
        }
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let frameCount = Int(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            debugLog("Failed to create audio format", level: .error, category: .audio)
            endBackgroundTask()
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            debugLog("Failed to create audio buffer", level: .error, category: .audio)
            endBackgroundTask()
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        if let channelData = buffer.floatChannelData {
            channelData[0].initialize(repeating: 0.0, count: Int(buffer.frameLength))
        }
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        do {
            try audioSession?.setActive(true, options: [])
            try audioEngine.start()
            playerNode.volume = 0.0
            playerNode.play()
            
            // Store references
            self.backgroundEngine = audioEngine
            self.backgroundPlayerNode = playerNode
            
            // Schedule with recursion limit to prevent infinite loop
            var scheduleCount = 0
            let maxSchedules = 3600 // 1 hour at 1 second per buffer
            
            func scheduleBuffer() {
                guard let engine = self.backgroundEngine,
                      engine.isRunning,
                      scheduleCount < maxSchedules else {
                    if scheduleCount >= maxSchedules {
                        print("⚠️ Max schedule count reached - restarting background audio")
                        self.stopBackgroundAudio()
                        self.startBackgroundAudio()
                    }
                    return
                }
                
                scheduleCount += 1
                playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                    scheduleBuffer()
                }
            }
            scheduleBuffer()
            
            debugLog("Background audio started with task ID: \(backgroundTaskID)", level: .success, category: .background)
            
        } catch {
            debugLog("Failed to start background audio: \(error.localizedDescription)", level: .error, category: .background)
            endBackgroundTask()
            
            // Retry after a delay if it's an XPC or session issue
            if error.localizedDescription.contains("XPC") || error.localizedDescription.contains("interrupted") {
                debugLog("Retrying background audio setup after interruption...", level: .warning, category: .background)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startBackgroundAudio()
                }
            }
        }
    }
    
    private func stopBackgroundAudio() {
        backgroundPlayerNode?.stop()
        backgroundEngine?.stop()
        backgroundPlayerNode = nil
        backgroundEngine = nil
        endBackgroundTask()
        debugLog("Background audio stopped", level: .info, category: .background)
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            debugLog("Background task ended", level: .success, category: .background)
        }
    }
    
    // Test function to verify slider functionality
    // Run asynchronously to avoid blocking main thread
    func testSliderFunctionality() {
        guard let slider = volumeSlider else {
            debugLog("TEST FAILED: No volume slider available", level: .error, category: .slider)
            sliderStatus = "NOT AVAILABLE for testing"
            return
        }
        
        // Run test asynchronously to avoid blocking
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let currentVolume = AVAudioSession.sharedInstance().outputVolume
            // Test by reducing volume slightly (only if we can reduce)
            // Don't test if volume is already very low
            guard currentVolume > 0.15 else {
                debugLog("TEST SKIPPED: Volume too low to test safely", level: .info, category: .slider)
                self.sliderStatus = "Found (volume too low to test)"
                return
            }
            
            let testVolume = max(0.1, currentVolume - 0.05) // Reduce by 5% for test
            
            debugLog("Testing slider functionality...", level: .info, category: .slider)
            debugLog("Current system volume: \(Int(currentVolume * 100))%, Test target: \(Int(testVolume * 100))%", level: .debug, category: .slider)
            
            let originalSliderValue = slider.value
            slider.value = testVolume
            slider.sendActions(for: .valueChanged)
            
            // Check after a delay - use background queue to avoid blocking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                let newVolume = AVAudioSession.sharedInstance().outputVolume
                let sliderValue = slider.value
                
                debugLog("Test results: Slider value: \(Int(sliderValue * 100))%, Actual system volume: \(Int(newVolume * 100))%, Expected: \(Int(testVolume * 100))%", level: .debug, category: .slider)
                
                // Check if volume actually changed from original
                let volumeChanged = abs(newVolume - currentVolume) > 0.02
                // Check if it's close to target (within 5%)
                let closeToTarget = abs(newVolume - testVolume) < 0.05
                
                if closeToTarget {
                    debugLog("TEST PASSED: Slider is functional - volume changed to target", level: .success, category: .slider)
                    self.sliderStatus = "Found and TESTED - WORKING"
                    self.isSliderFunctional = true
                } else if volumeChanged {
                    debugLog("TEST PARTIAL: Slider changed volume but not to exact target. This may indicate partial functionality on this device", level: .warning, category: .slider)
                    self.sliderStatus = "Found but PARTIALLY FUNCTIONAL"
                    self.isSliderFunctional = true  // Still functional, just not precise
                } else {
                    debugLog("TEST FAILED: Slider value changed but system volume did not. CRITICAL: Ceiling enforcement will NOT work on this device", level: .error, category: .slider)
                    self.sliderStatus = "Found but NOT FUNCTIONAL - Ceiling enforcement disabled"
                    self.isSliderFunctional = false
                }
            }
        }
    }
    
    // Manual test function for debugging
    // Run asynchronously to avoid blocking main thread
    func forceEnforcementTest() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let currentVolume = AVAudioSession.sharedInstance().outputVolume
            debugLog("FORCE TEST: Current volume = \(Int(currentVolume * 100))%, Ceiling = \(Int(self.systemVolumeCeiling * 100))%", level: .info, category: .enforcement)
            debugLog("FORCE TEST: Slider available = \(self.volumeSlider != nil), Slider status = \(self.sliderStatus)", level: .debug, category: .slider)
            
            if currentVolume > self.systemVolumeCeiling {
                debugLog("FORCE TEST: Volume exceeds ceiling, attempting enforcement...", level: .info, category: .enforcement)
                self.setSystemVolume(self.systemVolumeCeiling)
            } else {
                debugLog("FORCE TEST: Volume does not exceed ceiling. To test enforcement, increase volume above ceiling first", level: .info, category: .enforcement)
            }
        }
    }
    
    deinit {
        monitoringTimer?.invalidate()
        audioSession?.removeObserver(self, forKeyPath: "outputVolume")
        NotificationCenter.default.removeObserver(self)
        stopBackgroundAudio()
        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }
}
