# Pace - Developer Guide

## Quick Start

### Prerequisites
- macOS 11.5+ with Xcode 14+
- Swift 5.9+
- Git

### Setup
```bash
git clone <repository-url>
cd pace
open pace.xcodeproj
```

### Build & Run
1. Open `pace.xcodeproj` in Xcode
2. Select the `pace` scheme
3. Press `Cmd+R` to build and run

### Configuration
Create `pace/Config.plist` (not in version control):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>POSTHOG_API_KEY</key>
    <string>your_api_key_here</string>
    <key>POSTHOG_HOST</key>
    <string>https://app.posthog.com</string>
</dict>
</plist>
```

**Note**: Analytics is optional. The app will work without `Config.plist`.

---

## Project Structure

```
pace/
├── pace/
│   ├── paceApp.swift              # Main app entry point
│   ├── ContentView.swift          # Overlay rendering
│   ├── FocusModeView.swift        # Focus message editor
│   ├── AnalyticsManager.swift     # Analytics (optional)
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── WelcomeScreen.swift
│   │   ├── HowToUseScreen.swift
│   │   └── FeaturesScreen.swift
│   └── Config.plist               # API keys (not in git)
├── REQUIREMENTS.md                # Complete feature spec
├── README.md                      # User-facing documentation
└── HOW_TO_USE.md                  # This file
```

---

## Key Components

### GlobalHotkeyManager
- Uses Carbon API (`RegisterEventHotKey`)
- **No permissions required!**
- Registers hotkeys: ⌃⌥O, ⌃⌥P, ⌃⌥K, ⌃⌥L, ⌃⌥F
- Located in `paceApp.swift` (lines 21-157)

### OverlayWindow
- Full-screen transparent window
- Window level: `.screenSaver`
- Mouse events pass through (`ignoresMouseEvents: true`)
- Located in `paceApp.swift` (lines 799-823)

### FocusConfiguration
- State model for current mode, size, background
- Persisted via `UserDefaults`
- Located in `ContentView.swift`

### Mouse Tracking
- 60 FPS polling via `Timer`
- Smooth easing animation (0.15s)
- Multi-monitor support
- Located in `ContentView.swift`

---

## Development Tips

### Testing Onboarding
```bash
# Reset onboarding flag
defaults delete com.synw.pace hasSeenOnboarding

# Run app
open /path/to/pace.app
```

### Testing Hotkeys
- Hotkeys work globally (even when Xcode is focused)
- No permissions needed with Carbon API
- Test in a real build, not Xcode preview

### Debugging
- Check Console.app for print statements
- Use `print()` statements liberally
- Analytics events are logged to console

### Performance
- Use Instruments to profile
- Check CPU usage in Activity Monitor
- Target: <1% CPU when idle

---

## Common Tasks

### Update Version
1. Edit `pace/Info.plist`:
   - `CFBundleShortVersionString`: User-facing version (e.g., "1.0.3")
   - `CFBundleVersion`: Build number (increment each build)

### Add New Focus Mode
1. Add case to `FocusMode` enum in `ContentView.swift`
2. Implement rendering logic in `OverlayContentView`
3. Update menu in `setupMenuBar()` in `paceApp.swift`
4. Update cycling logic in `cycleNextFocusMode()`

### Add New Keyboard Shortcut
1. Add case to `HotkeyID` enum in `GlobalHotkeyManager`
2. Register hotkey in `setupHotkeys()`
3. Handle event in `handleEvent()`
4. Update menu to show shortcut

### Modify Onboarding
- Edit files in `pace/Onboarding/`
- Videos go in `pace/` directory (add to Xcode project)
- Update `OnboardingView.swift` for navigation

---

## Building for Release

### Clean Build
```bash
cd /path/to/pace
xcodebuild clean -scheme pace
xcodebuild -scheme pace -configuration Release build
```

### Code Signing
- Requires Apple Developer account
- Set up in Xcode: Signing & Capabilities tab
- Use "Developer ID Application" certificate for distribution

### Create ZIP
```bash
cd /path/to/DerivedData/pace-*/Build/Products/Release/
zip -r pace.zip pace.app
```

### Notarization (macOS)
```bash
xcrun notarytool submit pace.zip --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple pace.app
```

---

## Troubleshooting

### Hotkeys Not Working
- Ensure app is running (check menu bar icon)
- Check for conflicts with other apps
- Try restarting the app
- Carbon hotkeys don't require permissions!

### Overlay Not Showing
- Check if "Turn Off" is selected in menu
- Verify overlay window is created in `applicationDidFinishLaunching`
- Check window level (should be `.screenSaver`)

### Mouse Tracking Laggy
- Check timer interval (should be ~16ms for 60 FPS)
- Verify easing animation duration (0.15s)
- Profile with Instruments

### Build Errors
- Clean build folder: `Cmd+Shift+K`
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/pace-*`
- Restart Xcode

---

## Resources

- **Requirements**: See `REQUIREMENTS.md` for complete feature specification
- **Swift Documentation**: https://swift.org/documentation/
- **SwiftUI**: https://developer.apple.com/documentation/swiftui
- **Carbon API**: https://developer.apple.com/documentation/carbon
- **Sparkle**: https://sparkle-project.org/documentation/

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## License

See `LICENSE` file for details.
