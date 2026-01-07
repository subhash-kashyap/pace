# Pace - Reading Focus Tool Requirements

## Overview
Pace is a desktop application that provides a reading focus overlay to help users concentrate on specific areas of their screen. The app runs as a menu bar utility (macOS) / system tray (Windows/Linux) and provides multiple focus modes, keyboard shortcuts, and customization options.

---

## Core Functionality

### 1. Application Type
- **macOS**: Menu bar app (accessory app, no dock icon)
- **Windows/Linux**: System tray application
- **Mobile (iOS/Android)**: Full-screen app with gesture controls
- Runs persistently in background (desktop)
- Single instance only
- Optional: Launch on system startup

### 2. Focus Overlay System

#### 2.1 Overlay Window (Desktop)
- **Full-screen transparent window** covering entire primary display
- **Non-interactive**: Mouse/touch events pass through to underlying applications
- **Always on top**: Stays above all other windows (except focus message mode)
- **Multi-monitor support**: Tracks cursor position across all displays
- **Window level**: Above normal windows but below system UI elements

#### 2.1 Overlay View (Mobile)
- **Full-screen semi-transparent view** covering entire screen
- **Touch tracking**: Focus area follows touch position
- **Gesture support**: Swipe to change modes, pinch to resize
- **Orientation support**: Works in portrait and landscape

#### 2.2 Focus Modes (4 types)

**Rectangle Mode**
- Horizontal band that follows cursor/touch vertically
- Width: Full screen width
- Height: Configurable (200px base × size multiplier)
- Tracking: Vertical only (centered horizontally)

**Center Column Mode**
- Vertical column centered on screen
- Width: 70% of screen width
- Height: Configurable (200px base × size multiplier)
- Tracking: Vertical only (centered horizontally)
- Always horizontally centered regardless of cursor position

**Square Mode**
- Rectangular focus area that follows cursor/touch in both directions
- Width: 30% of screen width × size multiplier
- Height: 50% of screen height × size multiplier
- Tracking: Both horizontal and vertical
- Centered on cursor/touch position

**Circle Mode** (Default)
- Circular/elliptical focus area that follows cursor/touch
- Diameter: 50% of screen height × size multiplier
- Tracking: Both horizontal and vertical
- Centered on cursor/touch position

#### 2.3 Size Options (3 levels)
- **Small (S)**: 1.0× multiplier (base size)
- **Medium (M)**: 1.5× multiplier (Default)
- **Large (L)**: 2.25× multiplier (1.5 × 1.5)

Sizes apply to all focus modes proportionally.

#### 2.4 Background Styles (4 options)
- **Black**: Solid black (#000000, 100% opacity)
- **Black 70%**: Black with 70% opacity (Default)
- **White**: Solid white (#FFFFFF, 100% opacity)
- **White 70%**: White with 70% opacity

The background style determines the color of the dimmed area outside the focus region.

#### 2.5 Cursor/Touch Tracking
- **Polling rate**: 60 FPS (16.67ms interval)
- **Smoothing**: Eased animation (0.15s duration, ease-out curve)
- **Dead zone**: 0.5px threshold to prevent jitter
- **Multi-monitor** (desktop): Automatically detects which screen contains cursor
- **Touch tracking** (mobile): Follows primary touch point

### 3. Focus Message Mode

A distraction-free writing environment:

**Window/View Properties**
- Full-screen black background
- Centered text editor (700×450px on desktop, 90% screen on mobile)
- Close button (X) in top-right corner
- Above overlay window level

**Text Editor**
- Monospaced font (16pt)
- White text on black background
- White cursor
- Line spacing: 4pt
- No rich text formatting
- Undo/redo support
- Auto-saves text in memory (persists during session)

**Keyboard Shortcuts** (Desktop)
- ESC: Close focus message window
- Standard text editing shortcuts (Ctrl+A, Ctrl+C, Ctrl+V, etc.)

**Gestures** (Mobile)
- Swipe down from top: Close focus message
- Standard text selection gestures

### 4. Flash Mode (Pomodoro Timer)

Visual reminder system:

**Behavior**
- Toggle on/off from menu/settings
- When active: Shows visual flash every 25 minutes
- Flash animation: 6 pulses over 3 seconds (0.5s per pulse)
- Border: 8px gradient stroke (white → red, top-left → bottom-right)
- Opacity: Fades in/out (0 → 0.7 → 0)
- Full-screen overlay during flash

**Menu Integration** (Desktop)
- Shows "Flash" when inactive
- Shows "Flashed at [time]" after last flash
- Checkmark when active

**Settings Integration** (Mobile)
- Toggle switch in settings
- Shows last flash time
- Notification when flash triggers

### 5. Global Keyboard Shortcuts (Desktop Only)

**Hotkey System**
- Works system-wide (even when other apps are focused)
- Modifier combination: Control + Option (macOS) / Ctrl + Alt (Windows/Linux)
- **NO PERMISSIONS REQUIRED** (uses standard hotkey registration)

**Shortcuts**
- **⌃⌥O** (Ctrl+Alt+O): Cycle focus modes (Rectangle → Square → Center Column → Circle → repeat)
- **⌃⌥P** (Ctrl+Alt+P): Cycle sizes (S → M → L → repeat)
- **⌃⌥K** (Ctrl+Alt+K): Turn overlay off
- **⌃⌥L** (Ctrl+Alt+L): Cycle background styles (Black → Black 70% → White → White 70% → repeat)
- **⌃⌥F** (Ctrl+Alt+F): Toggle focus message window

**Implementation Requirements**
- **macOS**: Use Carbon API `RegisterEventHotKey` (NO Input Monitoring permission needed)
- **Windows**: Use `RegisterHotKey` API
- **Linux**: Use X11 `XGrabKey` or similar
- Shortcuts must be registered at app launch
- Gracefully handle conflicts with other apps

### 6. Side Panel Widget (Desktop Only)

**Appearance**
- Floating panel on right edge of screen
- Vertically centered
- Width: 270px (collapsed: 20px)
- Max height: 32% of screen height
- Black background (85% opacity)
- Rounded corners (12px radius)
- Drop shadow

**Collapsed State**
- Small vertical bar (8×80px)
- Color matches current background style (white for black bg, black for white bg)
- Click to expand

**Expanded State**
- Shows all menu options
- Scrollable if content exceeds max height
- Collapsible submenus for Size and Background
- Keyboard shortcuts displayed (grayed, right-aligned)
- Auto-collapses after selection

**Content**
- Turn On/Off (with ⌃⌥K shortcut)
- Focus modes (Rectangle, Square, Center Column, Circle) - first shows ⌃⌥O
- Size submenu (S, M, L) - first shows ⌃⌥P
- Background submenu (Black, Black 70%, White, White 70%) - first shows ⌃⌥L
- Show Focus Message (with ⌃⌥F shortcut)
- Flash toggle
- How to Use
- Check for Updates (desktop only)
- Quit Pace

### 7. Menu Bar / System Tray (Desktop)

**Icon**
- Flashlight symbol (filled)
- Monochrome (adapts to system theme)

**Menu Structure**
```
Turn Off                    ⌃⌥K
Rectangle                   ⌃⌥O
Square
Center Column
Circle
─────────────────────────────────
Size                           >
  S                         ⌃⌥P
  M
  L
BG                             >
  Black                     ⌃⌥L
  Black 70%
  White
  White 70%
─────────────────────────────────
Show Focus Message          ⌃⌥F
─────────────────────────────────
Flash
─────────────────────────────────
Breathe in - Breathe out, repeat (disabled)
─────────────────────────────────
Extras                         >
  How to Use
  Check for Updates...
─────────────────────────────────
Quit Pace
```

**Menu Behavior**
- Checkmark on active mode (only when overlay visible)
- Checkmark on "Turn Off" when overlay hidden
- Checkmark on current size
- Checkmark on current background style
- Checkmark on Flash when active
- Shortcuts shown in gray, right-aligned
- Only first item in cycling groups shows shortcut hint

### 8. Settings Screen (Mobile)

**Sections**
1. **Focus Mode**
   - Mode selector (Rectangle, Square, Center Column, Circle)
   - Size selector (S, M, L)
   - Background style selector (Black, Black 70%, White, White 70%)

2. **Features**
   - Flash mode toggle
   - Flash interval setting (default: 25 minutes)

3. **About**
   - App version
   - How to Use button
   - Privacy policy link
   - Rate the app

### 9. Onboarding Flow

**Trigger**
- First launch only (tracked via user preferences)
- Can be reopened via "How to Use" menu item / settings

**Screens**
1. **Welcome Screen**
   - App logo/icon
   - Title: "How it works"
   - Brief introduction
   - "Next" button

2. **How to Use Screen**
   - Video demonstration (looping, muted)
   - Instructions:
     - "Move your mouse to guide the focus area" (desktop)
     - "Touch and drag to guide the focus area" (mobile)
     - "Click the menu bar icon to change modes" (desktop)
     - "Open settings to change modes" (mobile)
   - "Next" button

3. **Features Screen**
   - Overview of keyboard shortcuts (desktop only)
   - Overview of gestures (mobile only)
   - Flash mode explanation
   - Focus message explanation
   - "Get Started" button

**Behavior**
- Full-screen white background
- Close button (X) in top-right
- ESC key closes onboarding (desktop)
- Swipe down closes onboarding (mobile)
- After completion: Show overlay with default settings
- Default for new users: Circle mode, Medium size, Black 70% background

### 10. State Persistence

**User Preferences (saved between sessions)**
- Current focus mode
- Current size
- Current background style
- Overlay visibility state (desktop only)
- Flash mode active/inactive
- Flash interval (minutes)
- Focus message text content
- Onboarding completion flag
- Last flash timestamp

**Storage**
- **macOS**: UserDefaults
- **Windows**: Registry or local JSON file
- **Linux**: JSON file in ~/.config/pace/
- **iOS**: UserDefaults
- **Android**: SharedPreferences

**Keys**
- `PaceFocusMode`: String (rectangle/square/centerColumn/circle)
- `PaceFocusSize`: String (S/M/L)
- `PaceBackgroundStyle`: String (black/black70/white/white70)
- `hasSeenOnboarding`: Boolean
- `focusMessageText`: String
- `flashInterval`: Integer (minutes, default: 25)

### 11. Analytics Integration (Optional)

**Events Tracked**
- App opened (with new_user flag)
- App closed
- Pace view shown (overlay activated)
- Pace view hidden (overlay deactivated) - includes duration
- Mode activated (mode name, size)
- Mode deactivated (mode name)
- Focus mode shown (focus message window)
- Focus mode hidden (focus message window) - includes duration
- Flash mode toggled (active/inactive)
- Flash triggered (visual flash shown)
- Onboarding completed

**Implementation**
- Use PostHog SDK (or equivalent analytics platform)
- API key stored in config file (not in version control)
- User ID: Generated UUID, persisted
- Session tracking: New session on app launch
- Privacy: No PII collected
- Optional: Allow users to opt-out

### 12. Auto-Update System (Desktop Only)

**Update Mechanism**
- **macOS**: Sparkle framework
- **Windows**: Squirrel.Windows or similar
- **Linux**: AppImage auto-update or manual

**Update Feed**
- RSS/XML feed hosted on GitHub
- Check interval: Daily (86400 seconds)
- Background checks (no interruption)
- User notification when update available

**Update Dialog**
- Shows version number
- Release notes (HTML formatted)
- "Install Update" and "Skip This Version" buttons
- Download and install in background

**Security**
- EdDSA signature verification
- HTTPS only for downloads
- Code signing required

---

## Technical Requirements

### Platform Support

**macOS**
- Minimum version: macOS 11.5 (Big Sur)
- Architecture: Universal binary (Intel + Apple Silicon)
- Language: Swift 5.9+
- UI Framework: SwiftUI + AppKit

**Windows**
- Minimum version: Windows 10 (version 1809 or later)
- Architecture: x64
- Language: C# (.NET 6+) or Electron
- UI Framework: WPF, WinUI 3, or Electron

**Linux**
- Distribution: Ubuntu 20.04+ or equivalent
- Architecture: x64
- Language: Python, Electron, or C++
- UI Framework: Qt, GTK, or Electron

**iOS**
- Minimum version: iOS 14.0
- Architecture: Universal (iPhone + iPad)
- Language: Swift 5.9+
- UI Framework: SwiftUI

**Android**
- Minimum version: Android 8.0 (API 26)
- Architecture: ARM64, x86_64
- Language: Kotlin or Java
- UI Framework: Jetpack Compose or XML layouts

### Permissions Required

**macOS**
- None! (Carbon hotkeys don't require Input Monitoring)

**Windows**
- None! (RegisterHotKey doesn't require special permissions)

**Linux**
- X11 access for hotkeys (standard)

**iOS**
- None

**Android**
- SYSTEM_ALERT_WINDOW (for overlay)
- FOREGROUND_SERVICE (for persistent overlay)

### Performance Requirements
- CPU usage: < 1% when idle
- Memory usage: < 50MB (desktop), < 30MB (mobile)
- Startup time: < 1 second
- Mouse/touch tracking latency: < 20ms
- Overlay rendering: 60 FPS minimum

### Code Architecture

**Separation of Concerns**
- App lifecycle management
- Window/view management (overlay, focus, flash, onboarding, side panel)
- State management (focus configuration, user preferences)
- Input handling (mouse/touch tracking, keyboard shortcuts)
- Analytics tracking (optional)
- Update checking (desktop only)

**Key Classes/Components**
- `AppDelegate` / `MainActivity`: Main app controller
- `OverlayWindow` / `OverlayView`: Transparent focus overlay
- `FocusWindow` / `FocusView`: Focus message editor
- `FlashWindow` / `FlashView`: Flash animation overlay
- `OnboardingWindow` / `OnboardingView`: Onboarding flow
- `SidePanelWindow`: Side widget (desktop only)
- `GlobalHotkeyManager`: Keyboard shortcut handler (desktop only)
- `GlobalMouseTracker` / `TouchTracker`: Input position polling
- `FocusConfiguration`: State model
- `AnalyticsManager`: Event tracking (optional)
- `UpdateManager`: Auto-update handling (desktop only)

---

## UI/UX Specifications

### Visual Design

**Colors**
- Overlay backgrounds: Pure black/white with opacity variants
- Side panel: Black 85% opacity (desktop)
- Settings background: System default (mobile)
- Text: White on dark backgrounds, black on light
- Shortcuts: Secondary label color (gray)
- Checkmarks: System accent color

**Typography**
- Menu items: System font, 13pt
- Shortcuts: System font, 11pt
- Focus message: Monospace, 16pt
- Side panel: System font, 13pt (11pt for headers)
- Mobile settings: System font, 16pt (14pt for secondary)

**Animations**
- Mouse/touch tracking: Ease-out, 0.15s
- Mode changes: Ease-out, 0.3s
- Side panel expand/collapse: Spring animation (0.3s, 0.8 damping)
- Flash pulses: Ease-in-out, 0.25s per pulse
- Mobile transitions: Standard platform animations

### Accessibility

**Keyboard Navigation** (Desktop)
- All features accessible via keyboard
- Standard shortcuts (Cmd+Q to quit, etc.)
- ESC to close modal windows
- Tab navigation in focus message editor

**Touch Navigation** (Mobile)
- All features accessible via touch
- Standard gestures (swipe, tap, pinch)
- VoiceOver/TalkBack support

**Screen Reader Support**
- Menu items have descriptive labels
- Icon has accessibility description
- Buttons have clear labels
- Proper semantic markup

**High Contrast**
- Overlay works with system high contrast mode
- Side panel maintains readability
- Focus message has high contrast (white on black)

---

## Configuration Files

### Config.plist / Config.json (Optional)
```
POSTHOG_API_KEY: Analytics API key (optional)
POSTHOG_HOST: Analytics endpoint URL (optional)
```

**Important**: Config file should NOT be in version control. Use `.gitignore`.

### Info.plist / App Manifest
```
CFBundleShortVersionString: 1.0.3
CFBundleVersion: 4
LSMinimumSystemVersion: 11.5 (macOS)
SUFeedURL: Update feed URL (desktop only)
SUPublicEDKey: Update signature public key (desktop only)
SUScheduledCheckInterval: 86400 (desktop only)
```

---

## Build & Distribution

### Build Process
1. Set version numbers in Info.plist/manifest
2. Build release configuration
3. Code sign with developer certificate
4. Create distribution package (ZIP for macOS, installer for Windows, APK/IPA for mobile)
5. Generate signature (desktop only)
6. Update appcast.xml with new version (desktop only)
7. Upload to distribution platform (GitHub, App Store, Play Store)
8. Push appcast.xml to repository (desktop only)

### Release Checklist
- [ ] Version numbers updated
- [ ] Release notes written
- [ ] Build tested on clean machine/device
- [ ] Code signed
- [ ] Notarized (macOS)
- [ ] Package created and signed
- [ ] Distribution platform release created
- [ ] Appcast.xml updated and pushed (desktop)
- [ ] Update verified in app

---

## Testing Requirements

### Manual Testing
- [ ] All focus modes work correctly
- [ ] All sizes apply properly
- [ ] All background styles render correctly
- [ ] Mouse/touch tracking is smooth and accurate
- [ ] Keyboard shortcuts work globally (desktop)
- [ ] Gestures work correctly (mobile)
- [ ] Focus message window opens/closes
- [ ] ESC/swipe closes focus message
- [ ] Flash mode triggers on schedule
- [ ] Side panel expands/collapses (desktop)
- [ ] Settings screen works (mobile)
- [ ] Menu bar shows correct states (desktop)
- [ ] Onboarding flows correctly
- [ ] Settings persist between launches
- [ ] Updates check and install (desktop)
- [ ] Multi-monitor support works (desktop)
- [ ] Orientation changes work (mobile)
- [ ] Performance is acceptable

### Edge Cases
- [ ] Rapid mode switching
- [ ] Rapid size cycling
- [ ] Multiple hotkey presses (desktop)
- [ ] Screen resolution changes
- [ ] Display disconnection/reconnection (desktop)
- [ ] Orientation changes (mobile)
- [ ] System sleep/wake
- [ ] Low memory conditions
- [ ] Permission denial handling (Android)
- [ ] Background/foreground transitions (mobile)

---

## Version History

### 1.0.3 (Current)
- Switched to Carbon hotkeys (NO permissions needed!)
- Updated keyboard shortcuts (K for off, L for background)
- Fixed video looping memory leak
- Improved observer lifecycle management

### 1.0.2
- Global keyboard shortcuts
- ESC key support in focus message
- Shortcuts displayed in menus
- Input Monitoring permission handling (deprecated)

### 1.0.1
- Improved menu UX
- Default to Circle mode
- Analytics improvements

### 1.0.0
- Initial release
- 4 focus modes
- 3 sizes
- 4 background styles
- Focus message mode
- Flash mode
- Onboarding
