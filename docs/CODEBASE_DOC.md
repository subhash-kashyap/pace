# Pace — Comprehensive Codebase Documentation

> **Version:** 1.0.3 | **Platform:** macOS 11.5+ | **Language:** Swift 5.9+ | **UI:** SwiftUI + AppKit

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [Core Data Models](#4-core-data-models)
5. [Windows & UI Layers](#5-windows--ui-layers)
6. [Key Classes & Components](#6-key-classes--components)
7. [Onboarding Flow](#7-onboarding-flow)
8. [Global Hotkey System](#8-global-hotkey-system)
9. [Analytics Integration](#9-analytics-integration)
10. [Auto-Update System (Sparkle)](#10-auto-update-system-sparkle)
11. [State Persistence](#11-state-persistence)
12. [Configuration & Secrets](#12-configuration--secrets)
13. [Build & Release](#13-build--release)
14. [Version History](#14-version-history)

---

## 1. Project Overview

**Pace** is a macOS menu-bar utility that creates a semi-transparent focus overlay on the screen to help users concentrate while reading. Inspired by the ADHD accessibility feature in [ux4g.gov.in](https://www.ux4g.gov.in/), it draws a "spotlight" window that follows the mouse cursor, dimming everything outside the focus area.

### Core Features

| Feature | Description |
|---|---|
| **Focus Overlay** | Full-screen transparent window; mouse events pass through |
| **4 Focus Modes** | Rectangle, Center Column, Square, Circle |
| **3 Sizes** | Small (1×), Medium (1.5×), Large (2.25×) |
| **4 Background Styles** | Black, Black 70%, White, White 70% |
| **Focus Message Mode** | Distraction-free full-screen text editor |
| **Flash Mode** | Pomodoro-style 25-min visual flash reminder |
| **Side Panel Widget** | Floating right-edge panel with all controls |
| **Global Hotkeys** | System-wide shortcuts via Carbon API (no permissions) |
| **Onboarding** | 3-screen first-launch walkthrough with video |
| **Auto-Updates** | Sparkle framework for in-app update delivery |
| **Analytics** | PostHog event tracking (optional, privacy-safe) |

---

## 2. Repository Structure

```
pace/                          # Root of repository
├── pace/                      # Main Swift source
│   ├── paceApp.swift          # App entry point, AppDelegate, all windows,
│   │                          #   GlobalHotkeyManager, SidePanel views
│   ├── ContentView.swift      # OverlayContentView, GlobalMouseTracker,
│   │                          #   FocusModeView, SimpleTextView
│   ├── FocusShape.swift       # Data models: FocusMode, FocusSize,
│   │                          #   BackgroundStyle, FocusConfiguration,
│   │                          #   all shape structs
│   ├── AnalyticsManager.swift # PostHog wrapper (singleton)
│   ├── Config.swift           # Reads API keys from plist/xcconfig
│   ├── Config.plist.template  # Template for secrets (not in git)
│   ├── Config.xcconfig        # Xcode build-level config variables
│   ├── Info.plist             # App metadata, Sparkle feed URL
│   ├── pace.entitlements      # macOS sandbox entitlements
│   ├── PaceFeatureOnbVid.mp4  # Demo video used in onboarding screen 2
│   ├── Assets.xcassets/       # App icon, image assets
│   ├── Preview Content/       # SwiftUI preview assets
│   └── Onboarding/
│       ├── OnboardingView.swift     # 3-page container + navigation
│       ├── WelcomeScreen.swift      # Page 1 – logo + title
│       ├── HowToUseScreen.swift     # Page 2 – video + instructions
│       ├── FeaturesScreen.swift     # Page 3 – feature list
│       └── AnimatedGIFView.swift    # (unused/helper)
├── pace.xcodeproj/            # Xcode project file
├── paceTests/                 # Unit test target (stub)
├── paceUITests/               # UI test target (stub)
├── docs/
│   └── analytics/
│       └── README.md          # PostHog setup & dashboard guide
├── scripts/                   # Build/release helper scripts
├── appcast.xml                # Sparkle RSS feed for auto-updates
├── REQUIREMENTS.md            # Full feature specification
├── HOW_TO_USE.md              # Developer guide
├── readme.md                  # User-facing README
└── LICENSE                    # MIT License
```

---

## 3. Architecture Overview

Pace uses an **AppKit-driven** architecture with **SwiftUI views embedded via `NSHostingView`**. There is no SwiftUI `WindowGroup`; instead, raw `NSWindow` subclasses are created and managed manually.

```
PaceApp (@main)
 └── AppDelegate (NSApplicationDelegate + ObservableObject)
      ├── GlobalHotkeyManager   ← Carbon API hotkeys
      ├── OverlayWindow         ← always-on-top transparent overlay
      │    └── OverlayContentView (SwiftUI)
      │         └── GlobalMouseTracker (60 FPS timer)
      ├── FocusWindow           ← full-screen black text editor
      │    └── FocusModeView (SwiftUI)
      │         └── SimpleTextView (NSViewRepresentable)
      ├── FlashWindow           ← Pomodoro flash border animation
      │    └── FlashBorderView (SwiftUI)
      ├── OnboardingWindow      ← first-launch 3-page flow
      │    └── OnboardingContainerView → OnboardingView
      │         ├── WelcomeScreen
      │         ├── HowToUseScreen (embeds SimpleVideoPlayer)
      │         └── FeaturesScreen
      ├── SidePanelWindow       ← floating right-edge widget
      │    └── SidePanelView
      │         ├── CollapsedSidePanel  (thin bar)
      │         └── ExpandedSidePanel   (full menu)
      └── NSStatusItem          ← menu bar icon + NSMenu
```

**Data flow:** `AppDelegate` holds a `@Published var focusConfiguration: FocusConfiguration` that all windows observe. Changes to mode/size/background are written to `UserDefaults` immediately and trigger SwiftUI re-renders.

---

## 4. Core Data Models

All defined in **`FocusShape.swift`**.

### `FocusMode` (enum)
```
case rectangle    → "rectangle"
case centerColumn → "centerColumn"
case square       → "square"
case circle       → "circle"  ← default for new users
```

### `FocusSize` (enum)
```
case small  = "S"  → multiplier 1.0
case medium = "M"  → multiplier 1.5   ← default
case large  = "L"  → multiplier 2.25
```

### `BackgroundStyle` (enum)
```
case black   → Color.black (100%)
case black70 → Color.black.opacity(0.7)  ← default
case white   → Color.white (100%)
case white70 → Color.white.opacity(0.7)
```

### `FocusConfiguration` (struct)
The central state model. Reads/writes from `UserDefaults` via static `current` computed property.

| UserDefaults Key | Type | Default |
|---|---|---|
| `PaceFocusMode` | String | `"circle"` |
| `PaceFocusSize` | String | `"M"` |
| `PaceBackgroundStyle` | String | `"black70"` |

**Computed dimensions** (dynamically scaled by size multiplier):

| Property | Formula |
|---|---|
| `rectangleHeight` | `200 × size.multiplier` px |
| `centerColumnSize` | width = `screenWidth × 0.7`, height = `200 × multiplier` |
| `squareSize` | width = `screenWidth × 0.3 × multiplier`, height = `screenHeight × 0.5 × multiplier` |
| `circleDiameter` | `screenHeight × 0.5 × multiplier` |

**Legacy migration:** Old mode strings `"small"` → `.rectangle/.small`; `"big"` → `.rectangle/.medium`.

### `FocusShape` (protocol)
```swift
protocol FocusShape {
    func createMask(in rect: CGRect, at position: CGPoint) -> Path
    var displayName: String { get }
}
```

Conformers: `RectangleShape`, `CenterColumnShape`, `SquareShape`, `CircleShape`, `HorizontalBandShape` (legacy).

---

## 5. Windows & UI Layers

Pace creates **5 `NSWindow` subclasses**, each at a different window level:

| Window | Level | Interactive | Purpose |
|---|---|---|---|
| `SidePanelWindow` | `maximumWindow` (highest) | ✅ Yes | Floating control widget |
| `FocusWindow` | `.statusBar` | ✅ Yes | Full-screen text editor |
| `OnboardingWindow` | `.statusBar` | ✅ Yes | First-launch onboarding |
| `OverlayWindow` | `.screenSaver` | ❌ Pass-through | The dimming overlay |
| `FlashWindow` | `.screenSaver` | ❌ Pass-through | Pomodoro flash border |

All windows use `styleMask: [.borderless, .fullSizeContentView]` and `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]` so they persist across Spaces and full-screen apps.

---

## 6. Key Classes & Components

### `AppDelegate` (`paceApp.swift:159`)

Central controller. Responsibilities:
- Launches all windows at startup
- Manages `NSStatusItem` (menu bar icon) and `NSMenu`
- Implements all `@objc` action handlers for menu items
- Owns the flash timer (`Timer`, 25 min interval)
- Tracks analytics session times (`overlayShownTime`, `focusModeShownTime`)
- Holds `SPUStandardUpdaterController` (Sparkle)

Key published properties:
```swift
@Published var focusConfiguration: FocusConfiguration
@Published var isFocusModeActive: Bool
@Published var isFlashModeActive: Bool
@Published var isSidePanelExpanded: Bool
@Published var focusText: String
```

Key methods:

| Method | Description |
|---|---|
| `applicationDidFinishLaunching` | Sets up everything; shows onboarding on first run |
| `setupMenuBar()` | Creates `NSMenu` with all items and submenus |
| `toggleOverlay()` | Shows/hides the overlay window |
| `applyFocusMode(_:)` | Changes mode, shows overlay, tracks analytics |
| `applyFocusSize(_:)` | Changes size, shows overlay, tracks analytics |
| `applyBackgroundStyle(_:)` | Changes BG, shows overlay |
| `cycleNextFocusMode()` | Hotkey handler — cycles modes in order |
| `cycleNextFocusSize()` | Hotkey handler — cycles sizes in order |
| `cycleBackgroundStyle()` | Hotkey handler — cycles backgrounds in order |
| `turnOffOverlay()` | Hotkey handler — hides overlay |
| `toggleFocusMode()` | Shows/hides Focus Message window; hides overlay while active |
| `toggleFlashMode()` | Starts/stops the 25-min flash timer |
| `showFlashBorder()` | Creates `FlashBorderView`, shows `FlashWindow`, runs 3s animation |
| `showOnboarding()` | Opens `OnboardingWindow` |
| `closeOnboarding()` | Closes onboarding; sets defaults on first use |

---

### `OverlayWindow` & `OverlayContentView` (`paceApp.swift:806`, `ContentView.swift:4`)

The heart of the app. `OverlayContentView` renders the dimming mask using SwiftUI's `Path` + `.blendMode(.destinationOut)` technique:

1. A full-screen `Rectangle` filled with the background color is drawn
2. Over it, a `Path` cutout (the focus shape) is subtracted using `.destinationOut` blend mode
3. Result: everything outside the focus shape is dimmed, inside is transparent

Mouse position is tracked by `GlobalMouseTracker` and injected as the `at:` parameter of `createMask(in:at:)`.

Animations:
- Mouse tracking: `.easeOut(duration: 0.15)` on both X and Y
- Mode/size/style changes: `.easeOut(duration: 0.3)`

---

### `GlobalMouseTracker` (`ContentView.swift:87`)

A `Timer`-based 60 FPS poller (no `NSEvent` monitor → **no Accessibility permission needed**).

- Polls `NSEvent.mouseLocation` every `1/60` seconds
- Converts global screen coords to window-local coords (handles multi-monitor)
- Dead-zone: ignores changes < 0.5 px to prevent jitter
- Runs on both `.common` and `.eventTracking` RunLoop modes

---

### `FocusWindow` & `FocusModeView` (`paceApp.swift:832`, `ContentView.swift:139`)

Full-screen black window for distraction-free writing.

- `canBecomeKey = true` → receives keyboard input
- ESC key intercepted in `performKeyEquivalent(with:)` → calls `toggleFocusMode()`
- Content: `SimpleTextView` (700×450 pt) — an `NSViewRepresentable` wrapping `NSTextView`
  - Monospaced 16pt font, white on black, 4pt line spacing
  - Undo/redo support (`allowsUndo = true`)
  - Text persisted in `AppDelegate.focusText` (in-memory, session only)

---

### `FlashWindow` & `FlashBorderView` (`paceApp.swift:880`, `paceApp.swift:1348`)

Pomodoro timer visual alert.

- Timer: `Timer.scheduledTimer(withTimeInterval: 25 * 60, repeats: true)`
- Animation: `LinearGradient` (white → red, top-left → bottom-right) border, 8px
- 6 pulses × 0.5s each = 3 seconds total, opacity 0 → 0.7 → 0 (ease-in-out)
- `onComplete` callback hides the window after animation

---

### `SidePanelWindow` / `SidePanelView` (`paceApp.swift:906`)

Floating panel on the right edge. Two states controlled by `AppDelegate.isSidePanelExpanded`:

**Collapsed (`CollapsedSidePanel`):** 8×80 px rounded bar. Color adapts to background style (white bar on black overlay, black bar on white overlay). Click expands.

**Expanded (`ExpandedSidePanel`):** 220px wide panel with:
- All focus mode buttons (with ⌃⌥O shortcut hint on first)
- Collapsible **Size** submenu (⌃⌥P on first)
- Collapsible **BG** submenu (⌃⌥L on first)
- Show Focus Message (⌃⌥F)
- Flash toggle
- How to Use
- Check for Updates
- Quit Pace

Max height = 32% of screen height (scrollable). Spring animation on expand/collapse (0.3s, 0.8 damping). Auto-collapses after any selection.

---

## 7. Onboarding Flow

Triggered on first launch (`hasSeenOnboarding` UserDefaults key). Can be re-opened from Extras menu / side panel.

### Screens

| Page | File | Content |
|---|---|---|
| 1 — Welcome | `WelcomeScreen.swift` | App logo + title |
| 2 — How It Works | `HowToUseScreen.swift` | Looping muted MP4 video (`PaceFeatureOnbVid.mp4`) + text instructions |
| 3 — Features | `FeaturesScreen.swift` | Icon rows: 4 Modes, Focus Message, Flash blinker |

### Navigation
- Back / Next buttons + 3-dot page indicator
- ESC key closes onboarding (handled in `OnboardingWindow.keyDown`)
- "Get Started" on page 3 → sets `hasSeenOnboarding = true` → calls `trackOnboardingCompleted()` → calls `closeOnboarding()`

### After Onboarding
On first completion, defaults are set:
- Mode: `.circle`, Size: `.medium`, Background: `.black70`
- Overlay is shown immediately

### Video Player
`SimpleVideoPlayer` is an `NSViewRepresentable` wrapping `AVPlayer` + `AVPlayerLayer`.
- Muted, auto-plays, loops via `NotificationCenter` (`AVPlayerItemDidPlayToEndTime`)
- Observer stored in `Coordinator` for proper cleanup on `deinit`

---

## 8. Global Hotkey System

**File:** `paceApp.swift:22` — `GlobalHotkeyManager`

Uses macOS **Carbon API** (`RegisterEventHotKey`) — **requires zero permissions**.

| Hotkey | Key Code | Action |
|---|---|---|
| ⌃⌥O | 31 | `cycleNextFocusMode()` — Rectangle → Square → Center Column → Circle |
| ⌃⌥P | 35 | `cycleNextFocusSize()` — S → M → L |
| ⌃⌥K | 40 | `turnOffOverlay()` |
| ⌃⌥L | 37 | `cycleBackgroundStyle()` |
| ⌃⌥F | 3 | `toggleFocusMode()` (Focus Message) |

Modifier combo: `optionKey | controlKey`

App signature used: `0x50414345` ("PACE"). The event handler is installed with `InstallEventHandler` on `GetApplicationEventTarget()`. All actions dispatched on `DispatchQueue.main`.

---

## 9. Analytics Integration

**File:** `AnalyticsManager.swift` — singleton (`AnalyticsManager.shared`)

**SDK:** [PostHog iOS SDK](https://github.com/PostHog/posthog-ios)

### Configuration
API key is loaded at startup from (in priority order):
1. `Info.plist` → `POSTHOG_API_KEY` (set via `Config.xcconfig`)
2. `pace/Config.plist` (local file, not in git)
3. Falls back to empty string — analytics silently disabled

Default host: `https://us.i.posthog.com`

### User Identity
Anonymous UUID generated once, stored in `UserDefaults` under `posthog_user_id`. No PII collected.

### Tracked Events

| Event | Properties | Trigger |
|---|---|---|
| `app_opened` | `is_new_user` | App launches |
| `app_closed` | `session_duration_seconds` | App quits |
| `pace_view_shown` | — | Overlay shown |
| `pace_view_hidden` | `view_duration_seconds` | Overlay hidden |
| `mode_activated` | `mode`, `size` | Mode/size selected |
| `mode_deactivated` | `mode`, `duration_seconds` | Mode changed/app closed |
| `focus_mode_shown` | — | Focus Message opened |
| `focus_mode_hidden` | `duration_seconds` | Focus Message closed |
| `flash_mode_toggled` | `is_active` | Flash on/off |
| `flash_triggered` | — | Flash animation played |
| `onboarding_completed` | — | User clicks "Get Started" |

Debug mode enabled (`config.debug = true`). Events flushed immediately (`flushAt = 1`) — suitable for testing but should be changed for production.

---

## 10. Auto-Update System (Sparkle)

**Framework:** [Sparkle](https://sparkle-project.org/) — `SPUStandardUpdaterController`

- Initialized in `applicationDidFinishLaunching` with `startingUpdater: true`
- Check interval: 86400 seconds (daily), configured in `Info.plist` via `SUScheduledCheckInterval`
- Feed URL: `SUFeedURL` in `Info.plist` → points to `appcast.xml` on GitHub
- Manual check: "Check for Updates…" menu item → `updaterController?.checkForUpdates(nil)`
- Security: EdDSA signature (`SUPublicEDKey` in `Info.plist`); HTTPS only

**`appcast.xml`** is an RSS feed listing each release:
- Current entries: v1.0.0, v1.0.1, v1.0.2
- Each item has title, HTML release notes, pubDate, Sparkle version tags, and a signed `<enclosure>` pointing to a GitHub Releases ZIP

---

## 11. State Persistence

All preferences stored in `UserDefaults.standard`:

| Key | Type | Description |
|---|---|---|
| `PaceFocusMode` | String | Active focus mode |
| `PaceFocusSize` | String | Active size |
| `PaceBackgroundStyle` | String | Active background style |
| `hasSeenOnboarding` | Bool | Whether onboarding was completed |
| `focusMessageText` | — | (In-memory only — not persisted to UserDefaults) |
| `posthog_user_id` | String | Anonymous analytics UUID |

**Note:** Focus message text is stored in `AppDelegate.focusText` (`@Published`) — it persists within the session but is lost on quit.

---

## 12. Configuration & Secrets

**`Config.plist.template`** (in git) — copy to `Config.plist` (gitignored):
```xml
<dict>
  <key>POSTHOG_API_KEY</key>
  <string>your_key_here</string>
  <key>POSTHOG_HOST</key>
  <string>https://app.posthog.com</string>
</dict>
```

**`Config.xcconfig`** — can inject keys at build time as `Info.plist` variables. `Config.swift` checks `Info.plist` first, then `Config.plist`.

Analytics is **fully optional** — the app functions normally with an empty API key.

---

## 13. Build & Release

### Prerequisites
- macOS 11.5+, Xcode 14+, Swift 5.9+
- Apple Developer account for signing/notarization

### Quick Start
```bash
git clone <repo>
cd pace
open pace.xcodeproj
# Cmd+R to build and run
```

### Release Process
1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`
2. Run `xcodebuild -scheme pace -configuration Release build`
3. Code-sign with "Developer ID Application" certificate
4. Notarize: `xcrun notarytool submit pace.zip --keychain-profile "AC_PASSWORD" --wait`
5. Staple: `xcrun stapler staple pace.app`
6. Generate EdDSA signature for the ZIP (Sparkle `sign_update` tool)
7. Add new `<item>` to `appcast.xml` with the signature
8. Push `appcast.xml` to GitHub (Sparkle polls the raw URL)
9. Upload ZIP to GitHub Releases

### Useful Commands
```bash
# Reset onboarding for testing
defaults delete com.synw.pace hasSeenOnboarding

# Clean build
xcodebuild clean -scheme pace

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/pace-*
```

---

## 14. Version History

| Version | Date | Highlights |
|---|---|---|
| **1.0.3** | Current | Carbon hotkeys (no permissions needed), new shortcuts K/L, fixed video looping memory leak, improved observer lifecycle |
| **1.0.2** | Dec 2024 | Global keyboard shortcuts (Input Monitoring — deprecated approach), ESC in focus message, shortcuts in menus |
| **1.0.1** | Nov 2025 | Improved menu UX, Circle as default mode, analytics fixes |
| **1.0.0** | Nov 2025 | Initial release — 4 modes, 3 sizes, 4 BG styles, focus message, flash, onboarding |

---

*Generated: 2026-04-30 | Covers all files in `/pace/pace/` and supporting docs*
