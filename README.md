# VolumeCrisis 📱🔊

An iOS app that helps you manage your device volume and maintain healthy listening habits.

## What It Does

VolumeCrisis helps you:
- **Control system volume** on your iPhone or iPad
- **Set a safety ceiling** - automatically prevents volume from going too high
- **Save volume presets** - quick access to your favorite volume levels
- **Get reminders** - optional hourly notifications to check your volume
- **Monitor volume** - works across all apps (YouTube, Music, etc.)
- **Debug & diagnose** - comprehensive logging system for troubleshooting

## Features

### Volume Management
- System volume control (iPhone: slider, iPad: use physical buttons)
- Safety ceiling that automatically enforces maximum volume
- App volume control for testing
- Test sound to verify your settings
- Real-time volume monitoring with background enforcement

### Volume Presets
- Save and quickly access favorite volume levels
- Edit or delete presets anytime
- Presets automatically respect safety ceiling
- Multiple presets for different scenarios (Evening, Normal, YouTube, Music, Podcasts)

### Smart Monitoring
- Automatically monitors volume changes in the background
- Enforces safety ceiling across all apps
- Event-driven monitoring (battery efficient)
- Optional hourly volume reminders
- Volume guide with recommended levels for different content types

### Debug & Diagnostics
- **Built-in debug logger** with categorized logs (Volume, Audio, UI, Background, Enforcement, Slider)
- **Log levels** (Debug, Info, Warning, Error, Success) with color coding
- **Real-time debug view** accessible from the main screen
- **Filter logs** by category and level
- **Toggle debug logging** on/off
- **Clear logs** functionality
- Detailed diagnostics for volume slider functionality
- Enforcement statistics (success/failure counts)
- Last enforcement attempt tracking

### Siri Shortcuts Integration
- **Set Volume Ceiling** - "Hey Siri, set volume ceiling to 50%"
- **Get Volume Ceiling** - "Hey Siri, what's my volume ceiling?"
- **Get Current Volume** - "Hey Siri, what's my current volume?"
- Works with Siri and the Shortcuts app

## Getting Started

1. **Clone and open the project**
   ```bash
   git clone https://github.com/KarMarsten/VolumeCrisis.git
   cd VolumeCrisis
   open VolumeCrisis.xcodeproj
   ```

2. **Build and run** in Xcode (Cmd + R)

## How to Use

### First Time Setup
1. Set your system volume safety ceiling (maximum allowed volume)
2. Adjust system volume:
   - **iPhone**: Use the slider in the app
   - **iPad**: Use physical volume buttons
3. Create volume presets for different scenarios
4. (Optional) Enable volume reminders
5. (Optional) Enable debug logging for troubleshooting

### Daily Usage
- **Control volume** using the app (iPhone) or physical buttons (iPad)
- **Set safety ceiling** - the app will automatically prevent volume from exceeding this
- **Use presets** - tap preset buttons for quick volume changes
- **Edit presets** - use the pencil icon to modify, trash icon to delete
- **Test sound** - verify your volume settings
- **View debug logs** - tap "Show Debug Logs" to see detailed system information

### Using Siri Shortcuts
1. Open the Shortcuts app
2. Find VolumeCrisis shortcuts in the app shortcuts section
3. Add shortcuts to Siri or create automations
4. Use voice commands like:
   - "Set volume ceiling to 50%"
   - "What's my volume ceiling?"
   - "Check my current volume"

### Debug Features
- **Enable/Disable Debug Logging**: Toggle at the bottom of the main screen
- **View Logs**: Tap "Show Debug Logs" to see all system events
- **Filter Logs**: Use category and level filters to find specific information
- **Clear Logs**: Use "Clear Debug Logs" to reset the log history
- **Diagnostics**: View slider status, enforcement statistics, and system state

## Important Notes

### System Volume Control
- **iPhone**: Full control via app slider
- **iPad**: Use physical volume buttons to change volume. The app monitors and enforces the ceiling automatically.
- Some older iPad models may have limited programmatic volume control due to iOS restrictions

### Ceiling Enforcement
- Works on iPhone and iPad (all models)
- Automatically reduces volume if it exceeds your safety ceiling
- Works across all apps (YouTube, Music, etc.)
- Requires the app to be running (foreground or background)
- Uses background audio to maintain monitoring capability
- Enforcement statistics tracked for diagnostics

### Debug Logging
- Debug logging is enabled by default
- Logs are stored in memory (last 500 entries)
- Logs are cleared when the app is closed
- Use debug logs to diagnose volume control issues
- All logs are color-coded by severity level

### Other Notes
- App volume controls only affect the app's test sound
- For best results, test on a physical device (simulator may have limitations)
- Background monitoring requires background audio permission
- Volume ceiling enforcement may take a moment to activate

## Privacy

- All data is stored locally on your device
- No personal information is transmitted
- Your settings remain private
- Debug logs are stored only in memory and never transmitted

## Battery Usage

The app is designed to be battery-efficient:
- Uses event-driven monitoring (not constant checking)
- Minimal background impact
- Optimized for long-running use
- Background audio uses silent buffers to maintain monitoring

## Requirements

- iOS 18.5 or later
- iPhone, iPad, or iPod touch
- Xcode 16.4 or later (for development)

## Architecture

### Core Components
- **SystemVolumeMonitor**: Monitors and controls system volume, enforces ceiling
- **AudioManager**: Manages app-level audio and test sounds
- **UserManager**: Handles user profiles and presets
- **DebugLogger**: Comprehensive logging system with categories and levels
- **SetVolumeCeilingIntent**: Siri Shortcuts integration

### Key Technologies
- SwiftUI for user interface
- AVFoundation for audio management
- MediaPlayer for system volume control
- AppIntents for Siri Shortcuts
- UserNotifications for reminders

## Troubleshooting

### Volume Control Not Working
1. Check debug logs for error messages
2. Verify volume slider status in diagnostics
3. Ensure app has been in foreground at least once
4. Try restarting the app
5. Check if running on iPad (may have limitations)

### Ceiling Not Enforcing
1. View enforcement statistics in diagnostics
2. Check debug logs for enforcement attempts
3. Verify volume slider is functional
4. Ensure app is running (foreground or background)
5. Check if device supports programmatic volume control

### Debug Logs
- Enable debug logging from the main screen
- View logs in real-time
- Filter by category to find specific issues
- Check for error-level messages

## Contributing

Contributions are welcome! Fork the repo, create a feature branch, and open a pull request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**VolumeCrisis** - Your companion for healthy listening habits! 🎧✨
