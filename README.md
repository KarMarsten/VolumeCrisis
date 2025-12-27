# VolumeCrisis 📱🔊

A comprehensive iOS volume management companion app built with SwiftUI that helps users maintain healthy listening habits and manage their audio experience.

## 🌟 Features

### 🎛️ Volume Management
- **Direct System Volume Control** - Control system volume directly from the app (iOS: full control via slider, iPadOS: monitoring only - use physical buttons)
- **System Volume Safety Ceiling** - Enforce maximum system volume for safety (works system-wide, automatically enforced on both iOS and iPadOS)
- **App Volume Ceiling** - Set maximum volume limits for app's test sound
- **Smart Volume Constraints** - Volume automatically adjusts when ceiling is reduced
- **Test Sound Playback** - Custom sine wave tone that respects volume settings

### 👤 User Profiles
- **Multiple User Support** - Create and switch between different user profiles
- **Personalized Settings** - Each user has their own volume preferences and presets
- **Volume Presets** - Save and quickly access favorite volume levels for different scenarios
- **Edit & Delete Presets** - Modify preset names/volumes or remove unwanted presets

### 📱 Smart Features
- **Background Execution** - App runs continuously in the background to monitor and enforce volume limits
- **System Volume Monitoring** - Automatically detects when device volume changes (from any app or physical buttons)
- **System Volume Enforcement** - Automatically reduces system volume if it exceeds the safety ceiling, even when changed from other apps
- **Cross-App Protection** - Ceiling enforcement works when volume is changed from YouTube, Music, or any other app
- **Volume Reminders** - Hourly notifications to check your volume levels
- **Volume Guide Cards** - Recommended volume levels for different content types:
  - YouTube (60%) - Video content
  - Music (40%) - Background music
  - Podcasts (70%) - Speech content
  - Gaming (50%) - Interactive content

### 🎨 Modern UI
- **Clean Interface** - Organized sections with proper spacing and visual hierarchy
- **Scrollable Content** - Smooth scrolling with visible indicators
- **Color-Coded Zones** - Visual feedback for volume levels (Low, Medium, High, Max)
- **Responsive Design** - Works on all iOS devices

## 🚀 Getting Started

### Prerequisites
- Xcode 14.0 or later
- iOS 18.5 or later
- macOS 13.0 or later (for development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/KarMarsten/VolumeCrisis.git
   cd VolumeCrisis
   ```

2. **Open in Xcode**
   ```bash
   open VolumeCrisis.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 📖 Usage Guide

### First Time Setup
1. **Select a User** - Choose from existing users or create a new profile
2. **Set System Volume Safety Ceiling** - Establish maximum allowed system volume (enforced system-wide)
3. **Adjust System Volume** - 
   - **iOS (iPhone)**: Use the system volume slider to set your preferred volume
   - **iPadOS (iPad)**: Use physical volume buttons, then the app will enforce the safety ceiling
4. **Set App Volume Ceiling** - Establish maximum volume limit for app's test sound
5. **Create Presets** - Add volume presets for different scenarios
6. **Enable Reminders** - Turn on volume check notifications

### Daily Usage
- **Control System Volume** - 
  - **iOS**: Use the blue system volume slider to adjust volume (works for all apps, respects ceiling)
  - **iPadOS**: Use physical volume buttons to change volume, app automatically enforces ceiling within 2 seconds
- **Set Safety Ceiling** - Adjust the orange ceiling slider to set your maximum allowed volume (works on both iOS and iPadOS)
- **Adjust App Volume** - Use the app volume slider to set test sound volume
- **Quick Presets** - Tap preset buttons for instant volume changes
- **Edit Presets** - Tap the pencil icon to modify preset name or volume
- **Delete Presets** - Tap the trash icon to remove unwanted presets
- **Monitor Levels** - Check the volume guide for recommended levels
- **Stay Aware** - Respond to volume reminder notifications
- **Cross-App Protection** - The app automatically enforces your ceiling even when using other apps like YouTube, Music, etc.

### Volume Controls
- **System Volume Slider** - 
  - **iOS**: Blue slider to directly control iPhone system volume (affects all apps, limited by ceiling)
  - **iPadOS**: Gray read-only display showing current volume (use physical buttons to change)
- **System Volume Safety Ceiling** - Orange slider to set maximum allowed system volume (enforced automatically on both platforms)
- **App Volume Slider** - Controls app's test sound volume (0-100%)
- **App Volume Ceiling** - Red slider sets maximum allowed app volume
- **Preset Buttons** - Quick access to saved volume levels (tap to apply)
- **Edit Button** - Pencil icon next to each preset to modify it
- **Delete Button** - Trash icon next to each preset to remove it
- **Test Sound** - Verify volume settings with custom tone

## 🏗️ Architecture

### Core Components
- **AudioManager** - Handles audio playback and volume control for app's test sound
- **SystemVolumeMonitor** - Monitors system volume, enforces safety ceiling, manages background execution, and detects iOS vs iPadOS
- **UserManager** - Manages user profiles, presets, and settings with persistent storage
- **ContentView** - Main UI and user interactions with platform-specific controls
- **UserProfile** - Data model for user information and volume presets

### Key Features
- **@Published Properties** - Real-time UI updates
- **ObservableObject** - State management across views
- **AVAudioEngine** - Custom audio generation for volume testing
- **UserNotifications** - Volume reminder system

## 🔧 Technical Details

### Audio System
- Custom sine wave generation for test sounds
- Volume control that respects ceiling limits
- Fallback to system sounds when needed
- Proper audio session management
- Background audio session for continuous execution
- System volume monitoring via AVAudioSession KVO (event-driven, battery efficient)
- Direct system volume control via MPVolumeView (works on iOS, limited on iPadOS)
- System volume safety ceiling enforcement (automatically reduces volume when exceeded)
- Real-time system volume monitoring and enforcement across all apps
- Silent audio loop to maintain background execution for continuous monitoring
- Optimized for battery life: 1-second audio buffers and 2-second volume check intervals
- Priority-based ceiling enforcement (bypasses other operations to ensure safety)

### Data Management
- In-memory user profiles and presets
- Persistent notification settings
- Real-time volume state tracking

### UI/UX Design
- SwiftUI for modern, declarative UI
- Responsive layout with proper spacing
- Accessibility considerations
- Dark mode support

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Development Guidelines
- Follow SwiftUI best practices
- Maintain consistent code style
- Add comments for complex logic
- Test on multiple device sizes

## 📱 Supported Devices

- iPhone (iOS 18.5+)
- iPad (iPadOS 18.5+)
- iPod touch (iOS 18.5+)

## 🔒 Privacy & Permissions

### Required Permissions
- **Notifications** - For volume reminder alerts
- **Audio** - For test sound playback and background execution
- **Background Modes** - Audio background mode enabled for continuous operation

### Data Storage
- All data is stored locally on device
- No personal information is transmitted
- User profiles and settings remain private

## 🐛 Known Issues & Limitations

- Test sound uses custom tone generation (system sounds don't respect volume settings)
- App volume controls only affect the app's test sound
- System volume control and ceiling enforcement require app to be running (foreground or background)
- **iPadOS Limitation**: System volume cannot be increased programmatically - use physical volume buttons. The app can only reduce volume to enforce the safety ceiling.
- **iOS Simulator Limitation**: System volume control may not work properly in the iOS Simulator. For full functionality, test on a physical device.
- **⚠️ CRITICAL: Older iPad Limitation**: On some older iPad models, programmatic system volume control is completely blocked by the OS. The app can detect this and will show a warning. **Ceiling enforcement will NOT work on these devices.** This is a hardware/OS restriction that cannot be bypassed with public APIs.

### Workarounds for Older iPads

If ceiling enforcement doesn't work on your device, use these iOS system features:

1. **Screen Time Volume Limit** (Recommended):
   - Settings > Screen Time > Content & Privacy Restrictions
   - Enable "Content & Privacy Restrictions"
   - Go to "Volume Limit" and set your maximum volume

2. **iOS Shortcuts**:
   - Create a shortcut that sets volume to your desired maximum
   - Run it manually or via automation

3. **Parental Controls**:
   - Use Family Sharing to set volume limits for child devices

## 🔋 Battery Usage

The app is optimized for battery efficiency:
- **Event-driven monitoring**: Uses KVO (Key-Value Observing) for real-time volume changes instead of constant polling
- **Efficient backup checks**: Volume checks run every 2 seconds as a backup (KVO handles most changes)
- **Optimized audio buffers**: 1-second silent buffers reduce CPU wake-ups by 90%
- **Continuous background execution**: App stays active to monitor volume changes from other apps
- **Low overhead**: Minimal battery impact when running in background

## 🚧 Future Enhancements

- [x] System volume control and safety ceiling (implemented)
- [x] Persistent data storage for presets and settings (implemented)
- [ ] Cloud sync for user profiles
- [ ] Advanced audio analysis
- [ ] Custom notification sounds
- [ ] Volume usage analytics
- [ ] Background execution statistics
- [ ] Configurable background execution behavior

For a detailed roadmap of upcoming features, see [FEATURE_IDEAS.md](FEATURE_IDEAS.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI and AVFoundation
- Inspired by the need for better volume management
- Designed for hearing health awareness

## 📞 Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check the troubleshooting section
- Review the usage guide

---

**VolumeCrisis** - Your companion for healthy listening habits! 🎧✨ 