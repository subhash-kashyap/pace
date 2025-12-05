# Pace - Reading Focus Tool Requirements

## Overview
Pace is a desktop application that provides a reading focus overlay to help users concentrate on specific areas of their screen. The app runs as a menu bar utility (system tray on Windows) and provides multiple focus modes, keyboard shortcuts, and customization options.

---

## Core Functionality

### 1. Application Type
- **macOS**: Menu bar app (accessory app, no dock icon)
- **Windows**: System tray application
- Runs persistently in background
- Single instance only
- Launches on system startup (optional user preference)

### 2. Focus Overlay System

#### 2.1 Overlay Window
- **Full-screen transparent window** that covers entire primary display
- **Non-interactive**: Mouse clicks pass through to underlying applications
- **Always on top**: Stays above all other windows (except focus message mode)
- **Multi-monitor support**: Tracks mouse position across all displays
- **Window level**: Above normal windows but below system UI elements

#### 2.2 Focus Modes (4 types)

**Rectangle Mode**
- Horizontal band that follows mouse vertically
- Width: Full screen width
- Height: Configurable (200px base × size multiplier)
- Mouse tracking: Vertical only (centered horizontally)

**Center Column Mode**
- Vertical column centered on screen
- Width: 70% of screen width
- Height: Configurable (200px base × size multiplier)
- Mouse tracking: Vertical only (centered horizontally)
- Always horizontally centered regardless of mouse position

**Square Mode**
- Rectangular focus area that follows mouse in both directions
- Width: 30% of screen width × size multiplier
- Height: 50% of screen height × size multiplier
- Mouse tracking: Both horizontal and vertical
- Centered on mouse cursor position

**Circle Mode**
- Circular/elliptical focus area that follows mouse
- Diameter: 50% of screen height × size multiplier
- Mouse tracking: Both horizontal and vertical
- Centered on mouse cursor position

#### 2.3 Size Options (3 levels)
- **Small (S)**: 1.0× multiplier (base size)
- **Medium (M)**: 1.5× multiplier
- **Large (L)**: 2.25× multiplier (1.5 × 1.5)

Sizes apply to all focus modes proportionally.

#### 2.4 Background Styles (4 options)
- **Black**: Solid black (#000000, 100% opacity)
- **Black 70%**: Black with 70% opacity
- **White**: Solid white (#FFFFFF, 100% opacity)
- **White 70%**: White with 70% opacity

The background style determines the color of the dimmed area outside the focus region.

#### 2.5 Mouse Tracking
- **Polling rate**: 60 FPS (16.67ms interval)
- **Smoothing**: Eased animation (0.12s duration, ease-out curve)
- **Dead zone**: 0.5px threshold to prevent jitter
- **Multi-monitor**: Automatically detects which screen contains cursor
- **Coordinate system**: Flipped Y-axis on macOS (origin top-left on Windows)

### 3. Focus Message Mode

A distraction-free writing environment:

**Window Properties**
- Full-screen black background
- Centered text editor (700×450px)
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

**Keyboard Shortcuts**
- ESC: Close focus message window
- Standard text editing shortcuts (Ctrl+A, Ctrl+C, Ctrl+V, etc.)

### 4. Flash Mode (Pomodoro Timer)

Visual reminder system:

**Behavior**
- Toggle on/off from menu
- When active: Shows visual flash every 25 minutes
- Flash animation: 6 pulses over 3 seconds (0.5s per pulse)
- Border: 8px gradient stroke (white → red, top-left → bottom-right)
- Opacity: Fades in/out (0 → 0.7 → 0)
- Full-screen overlay during flash

**Menu Integration**
- Shows "Flash" when inactive
- Shows "Flashed at [time]" after last flash
- Checkmark when active

### 5. Global Keyboard Shortcuts

**Hotkey System**
- Works system-wide (even when other apps are focused)
- Modifier combination: Control + Option (Ctrl + Alt on Windows)

**Shortcuts**
- **⌃⌥O** (Ctrl+Alt+O): Cycle focus modes (Rectangle → Square → Center Column → Circle → repeat)
- **⌃⌥P** (Ctrl+Alt+P): Cycle sizes (S → M → L → repeat)
- **⌃⌥L** (Ctrl+Alt+L): Turn overlay off
- **⌃⌥F** (Ctrl+Alt+F): Toggle focus message window

**Implementation Requirements**
- **macOS**: Use CGEventTap API (requires Input Monitoring permission)
- **Windows**: Use low-level keyboard hooks (RegisterHotKey or SetWindowsHookEx)
- Shortcuts must be captured before reaching active application
- Return/swallow event when handled, pass through when not

**First-time Setup**
- Request Input Monitoring permission (macOS) / Accessibility permission (Windows)
- Show helpful dialog explaining shortcuts
- Offer to open system settings
- Auto-relaunch after permission granted

### 6. Side Panel Widget

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
- Turn On/Off (with ⌃⌥L shortcut)
- Focus modes (Rectangle, Square, Center Column, Circle) - first shows ⌃⌥O
- Size submenu (S, M, L) - first shows ⌃⌥P
- Background submenu (Black, Black 70%, White, White 70%)
- Show Focus Message (with ⌃⌥F shortcut)
- Flash toggle
- How to Use
- Check for Updates
- Quit Pace

### 7. Menu Bar / System Tray

**Icon**
- Flashlight symbol (filled)
- Monochrome (adapts to system theme)

**Menu Structure**
```
Turn Off                    ⌃⌥L
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
  Black
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

### 8. Onboarding Flow

**Trigger**
- First launch only (tracked via user preferences)
- Can be reopened via "How to Use" menu item

**Screens**
1. **Welcome Screen**
   - App logo/icon
   - Brief introduction
   - "Get Started" button

2. **Features Screen**
   - Overview of focus modes
   - Visual examples
   - "Next" button

3. **How to Use Screen**
   - Keyboard shortcuts
   - Menu bar instructions
   - Side panel explanation
   - "Done" button

**Behavior**
- Full-screen white background
- Close button (X) in top-right
- ESC key closes onboarding
- After completion: Show overlay with default settings
- Default for new users: Circle mode, Medium size, Black 70% background

### 9. State Persistence

**User Preferences (saved between sessions)**
- Current focus mode
- Current size
- Current background style
- Overlay visibility state
- Flash mode active/inactive
- Focus message text content
- Onboarding completion flag
- Last flash timestamp

**Storage**
- **macOS**: UserDefaults
- **Windows**: Registry or local JSON file

**Keys**
- `PaceFocusMode`: String (rectangle/square/centerColumn/circle)
- `PaceFocusSize`: String (S/M/L)
- `PaceBackgroundStyle`: String (black/black70/white/white70)
- `hasSeenOnboarding`: Boolean
- `focusMessageText`: String

### 10. Analytics Integration

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
- API key stored in config file
- User ID: Generated UUID, persisted
- Session tracking: New session on app launch
- Privacy: No PII collected

### 11. Auto-Update System

**Update Mechanism**
- **macOS**: Sparkle framework
- **Windows**: Squirrel.Windows or similar

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

### Permissions Required

**macOS**
- Accessibility (for system-wide features)
- Input Monitoring (for global keyboard shortcuts)

**Windows**
- Accessibility/UI Automation (for overlay)
- Low-level keyboard hooks (for global shortcuts)

### Performance Requirements
- CPU usage: < 1% when idle
- Memory usage: < 50MB
- Startup time: < 1 second
- Mouse tracking latency: < 20ms
- Overlay rendering: 60 FPS minimum

### Code Architecture

**Separation of Concerns**
- App lifecycle management
- Window management (overlay, focus, flash, onboarding, side panel)
- State management (focus configuration, user preferences)
- Input handling (mouse tracking, keyboard shortcuts)
- Analytics tracking
- Update checking

**Key Classes/Components**
- `AppDelegate`: Main app controller
- `OverlayWindow`: Transparent focus overlay
- `FocusWindow`: Focus message editor
- `FlashWindow`: Flash animation overlay
- `OnboardingWindow`: Onboarding flow
- `SidePanelWindow`: Side widget
- `GlobalHotkeyManager`: Keyboard shortcut handler
- `GlobalMouseTracker`: Mouse position polling
- `FocusConfiguration`: State model
- `AnalyticsManager`: Event tracking
- `UpdateManager`: Auto-update handling

---

## UI/UX Specifications

### Visual Design

**Colors**
- Overlay backgrounds: Pure black/white with opacity variants
- Side panel: Black 85% opacity
- Text: White on dark backgrounds, black on light
- Shortcuts: Secondary label color (gray)
- Checkmarks: System accent color

**Typography**
- Menu items: System font, 13pt
- Shortcuts: System font, 11pt
- Focus message: Monospace, 16pt
- Side panel: System font, 13pt (11pt for headers)

**Animations**
- Mouse tracking: Ease-out, 0.15s
- Mode changes: Ease-out, 0.3s
- Side panel expand/collapse: Spring animation (0.3s, 0.8 damping)
- Flash pulses: Ease-in-out, 0.25s per pulse

### Accessibility

**Keyboard Navigation**
- All features accessible via keyboard
- Standard shortcuts (Cmd+Q to quit, etc.)
- ESC to close modal windows
- Tab navigation in focus message editor

**Screen Reader Support**
- Menu items have descriptive labels
- Icon has accessibility description
- Buttons have clear labels

**High Contrast**
- Overlay works with system high contrast mode
- Side panel maintains readability
- Focus message has high contrast (white on black)

---

## Configuration Files

### Config.plist / Config.json
```
POSTHOG_API_KEY: Analytics API key
POSTHOG_HOST: Analytics endpoint URL
```

### Info.plist / App Manifest
```
CFBundleShortVersionString: 1.0.2
CFBundleVersion: 3
LSMinimumSystemVersion: 11.5
SUFeedURL: Update feed URL
SUPublicEDKey: Update signature public key
SUScheduledCheckInterval: 86400
```

---

## Build & Distribution

### Build Process
1. Set version numbers in Info.plist/manifest
2. Build release configuration
3. Code sign with developer certificate
4. Create ZIP archive
5. Generate EdDSA signature
6. Update appcast.xml with new version
7. Upload to GitHub releases
8. Push appcast.xml to repository

### Release Checklist
- [ ] Version numbers updated (Info.plist, appcast.xml)
- [ ] Release notes written
- [ ] Build tested on clean machine
- [ ] Code signed
- [ ] Notarized (macOS)
- [ ] ZIP created and signed
- [ ] GitHub release created
- [ ] Appcast.xml updated and pushed
- [ ] Update verified in app

---

## Testing Requirements

### Manual Testing
- [ ] All focus modes work correctly
- [ ] All sizes apply properly
- [ ] All background styles render correctly
- [ ] Mouse tracking is smooth and accurate
- [ ] Keyboard shortcuts work globally
- [ ] Focus message window opens/closes
- [ ] ESC closes focus message
- [ ] Flash mode triggers on schedule
- [ ] Side panel expands/collapses
- [ ] Menu bar shows correct states
- [ ] Onboarding flows correctly
- [ ] Settings persist between launches
- [ ] Updates check and install
- [ ] Multi-monitor support works
- [ ] Performance is acceptable

### Edge Cases
- [ ] Rapid mode switching
- [ ] Rapid size cycling
- [ ] Multiple hotkey presses
- [ ] Screen resolution changes
- [ ] Display disconnection/reconnection
- [ ] System sleep/wake
- [ ] Low memory conditions
- [ ] Permission denial handling

---

## Future Enhancements (Not in v1.0.2)

- Custom keyboard shortcuts
- Multiple overlay profiles
- Hotkey to increase/decrease size with scroll
- Custom focus shapes
- Color customization
- Opacity slider
- Multi-monitor independent overlays
- Window-specific focus (follow active window)
- Reading speed tracking
- Focus session statistics
- Export focus message text
- Cloud sync of preferences

---

## Version History

### 1.0.2 (Current)
- Global keyboard shortcuts
- ESC key support in focus message
- Shortcuts displayed in menus
- Input Monitoring permission handling

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
