# VolumeCrisis 📱🔊

A comprehensive iOS volume management companion app built with SwiftUI that helps users maintain healthy listening habits and manage their audio experience.

## 🌟 Features

### 🎛️ Volume Management
- **Direct System Volume Control** - Control iPad system volume directly from the app (affects all apps including YouTube, Music, etc.)
- **System Volume Safety Ceiling** - Enforce maximum iPad system volume for safety (works system-wide, automatically enforced)
- **App Volume Ceiling** - Set maximum volume limits for app's test sound
- **Smart Volume Constraints** - Volume automatically adjusts when ceiling is reduced
- **Test Sound Playback** - Custom sine wave tone that respects volume settings

### 👤 User Profiles
- **Multiple User Support** - Create and switch between different user profiles
- **Personalized Settings** - Each user has their own volume preferences and presets
- **Volume Presets** - Save and quickly access favorite volume levels for different scenarios
- **Edit & Delete Presets** - Modify preset names/volumes or remove unwanted presets

### 📱 Smart Features
- **Background Execution** - App runs continuously in the background when device sound is on
- **System Volume Monitoring** - Automatically detects when device volume changes
- **System Volume Enforcement** - Automatically reduces system volume if it exceeds the safety ceiling
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
   open VolumeCrisis/VolumeCrisis.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 📖 Usage Guide

### First Time Setup
1. **Select a User** - Choose from existing users or create a new profile
2. **Set System Volume Safety Ceiling** - Establish maximum allowed iPad volume (enforced system-wide)
3. **Adjust System Volume** - Use the system volume slider to set your preferred iPad volume
4. **Set App Volume Ceiling** - Establish maximum volume limit for app's test sound
5. **Create Presets** - Add volume presets for different scenarios
6. **Enable Reminders** - Turn on volume check notifications

### Daily Usage
- **Control System Volume** - Use the blue system volume slider to adjust iPad volume (works for all apps)
- **Adjust App Volume** - Use the app volume slider to set test sound volume
- **Quick Presets** - Tap preset buttons for instant volume changes
- **Edit Presets** - Tap the pencil icon to modify preset name or volume
- **Delete Presets** - Tap the trash icon to remove unwanted presets
- **Monitor Levels** - Check the volume guide for recommended levels
- **Stay Aware** - Respond to volume reminder notifications

### Volume Controls
- **System Volume Slider** - Blue slider to directly control iPad system volume (affects all apps, limited by ceiling)
- **System Volume Safety Ceiling** - Orange slider to set maximum allowed iPad system volume (enforced automatically)
- **App Volume Slider** - Controls app's test sound volume (0-100%)
- **App Volume Ceiling** - Red slider sets maximum allowed app volume
- **Preset Buttons** - Quick access to saved volume levels (tap to apply)
- **Edit Button** - Pencil icon next to each preset to modify it
- **Delete Button** - Trash icon next to each preset to remove it
- **Test Sound** - Verify volume settings with custom tone

## 🏗️ Architecture

### Core Components
- **AudioManager** - Handles audio playback and volume control for app's test sound
- **SystemVolumeMonitor** - Monitors system volume, enforces safety ceiling, and manages background execution
- **UserManager** - Manages user profiles and settings
- **ContentView** - Main UI and user interactions
- **UserProfile** - Data model for user information

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
- Direct system volume control via MPVolumeView (controls actual iPad volume)
- System volume safety ceiling enforcement (automatically reduces volume when exceeded)
- Real-time system volume monitoring and enforcement
- Silent audio loop to maintain background execution when device sound is on
- Optimized for battery life: 1-second audio buffers and 5-second volume check intervals

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

## 🐛 Known Issues

- Test sound uses custom tone generation (system sounds don't respect volume settings)
- App volume controls only affect the app's test sound
- System volume control and ceiling enforcement require app to be running (foreground or background)
- Presets are stored in memory (will reset when app is closed)
- Background execution requires device sound to be on (volume > 0)

## 🔋 Battery Usage

The app is optimized for battery efficiency:
- **Event-driven monitoring**: Uses KVO (Key-Value Observing) for real-time volume changes instead of constant polling
- **Reduced timer frequency**: Volume checks run every 5 seconds as a backup (KVO handles most changes)
- **Optimized audio buffers**: 1-second silent buffers reduce CPU wake-ups by 90%
- **Automatic power management**: Background audio stops when device is muted, saving battery
- **Low overhead**: Minimal battery impact when running in background

## 🚧 Future Enhancements

- [x] System volume control and safety ceiling (implemented)
- [ ] Persistent data storage for presets
- [ ] Cloud sync for user profiles
- [ ] Advanced audio analysis
- [ ] Custom notification sounds
- [ ] Volume usage analytics
- [ ] Background execution statistics
- [ ] Configurable background execution behavior

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