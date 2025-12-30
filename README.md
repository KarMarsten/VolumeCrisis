# VolumeCrisis 📱🔊

An iOS app that helps you manage your device volume and maintain healthy listening habits.

## What It Does

VolumeCrisis helps you:
- **Control system volume** on your iPhone or iPad
- **Set a safety ceiling** - automatically prevents volume from going too high
- **Save volume presets** - quick access to your favorite volume levels
- **Get reminders** - optional hourly notifications to check your volume
- **Monitor volume** - works across all apps (YouTube, Music, etc.)

## Features

### Volume Management
- System volume control (iPhone: slider, iPad: use physical buttons)
- Safety ceiling that automatically enforces maximum volume
- App volume control for testing
- Test sound to verify your settings

### Volume Presets
- Save and quickly access favorite volume levels
- Edit or delete presets anytime

### Smart Monitoring
- Automatically monitors volume changes in the background
- Enforces safety ceiling across all apps
- Optional hourly volume reminders
- Volume guide with recommended levels for different content

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

### Daily Usage
- **Control volume** using the app (iPhone) or physical buttons (iPad)
- **Set safety ceiling** - the app will automatically prevent volume from exceeding this
- **Use presets** - tap preset buttons for quick volume changes
- **Edit presets** - use the pencil icon to modify, trash icon to delete
- **Test sound** - verify your volume settings

## Important Notes

### System Volume Control
- **iPhone**: Full control via app slider
- **iPad**: Use physical volume buttons to change volume. The app monitors and enforces the ceiling automatically.

### Ceiling Enforcement
- Works on iPhone and iPad (all models)
- Automatically reduces volume if it exceeds your safety ceiling
- Works across all apps (YouTube, Music, etc.)
- Requires the app to be running (foreground or background)

### Other Notes
- App volume controls only affect the app's test sound
- For best results, test on a physical device (simulator may have limitations)

## Privacy

- All data is stored locally on your device
- No personal information is transmitted
- Your settings remain private

## Battery Usage

The app is designed to be battery-efficient:
- Uses event-driven monitoring (not constant checking)
- Minimal background impact
- Optimized for long-running use

## Requirements

- iOS 18.5 or later
- iPhone, iPad, or iPod touch

## Contributing

Contributions are welcome! Fork the repo, create a feature branch, and open a pull request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**VolumeCrisis** - Your companion for healthy listening habits! 🎧✨
